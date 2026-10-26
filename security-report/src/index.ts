import fs from 'node:fs';
import path from 'node:path';
import * as core from '@actions/core';
import { DefaultArtifactClient } from '@actions/artifact';
import type { Log as SarifLog } from 'sarif';

interface Finding {
    ruleId: string;
    level: 'error' | 'warning' | 'note';
    file: string;
    line: number;
    message: string;
}

interface IssueComment {
    id: number;
    body?: string;
}

interface GitHubIssue {
    number: number;
    body?: string;
}

function escapeTableCell(val: unknown): string {
    return String(val ?? '')
        .replace(/\r?\n|\r/g, ' ')
        .replace(/\|/g, '\\|')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

async function fetchAllComments(apiBase: string, prNumber: number, headers: HeadersInit): Promise<IssueComment[]> {
    const allComments: IssueComment[] = [];
    for (let page = 1; page <= 3; page++) {
        const res = await fetch(`${apiBase}/issues/${prNumber}/comments?per_page=100&page=${page}`, { headers });
        if (!res.ok) break;
        const data = (await res.json()) as IssueComment[];
        if (!Array.isArray(data) || data.length === 0) break;
        allComments.push(...data);
        if (data.length < 100) break;
    }
    return allComments;
}

async function run(): Promise<void> {
    const sarifPath = core.getInput('sarif-file', { required: true });
    const title = core.getInput('title') || 'Security Scan Report';
    const commentTag = core.getInput('comment-tag') || 'security-report';
    const badgeLabel = core.getInput('badge-label') || 'Security';
    const token = core.getInput('github-token') || process.env.GITHUB_TOKEN || '';
    const failOnFindings = core.getInput('fail-on-findings') === 'true';
    const uploadArtifact = core.getInput('upload-artifact') !== 'false';
    const shouldManageIssue = core.getInput('manage-issue') === 'true';
    const issueTitle = core.getInput('issue-title') || '[Security Audit] Active Vulnerabilities Detected';

    if (!fs.existsSync(sarifPath) || fs.statSync(sarifPath).size === 0) {
        core.setFailed(`SARIF file missing or empty at path: ${sarifPath}`);
        return;
    }

    let sarif: SarifLog;
    try {
        sarif = JSON.parse(fs.readFileSync(sarifPath, 'utf8')) as SarifLog;
    } catch (err: unknown) {
        core.setFailed(`Failed to parse SARIF JSON: ${err instanceof Error ? err.message : String(err)}`);
        return;
    }

    const findings: Finding[] = [];
    const counts = { error: 0, warning: 0, note: 0 };

    for (const run of sarif.runs || []) {
        const rulesMap = new Map<string, { defaultConfiguration?: { level?: string } }>();
        for (const rule of run.tool?.driver?.rules || []) {
            rulesMap.set(rule.id, rule);
        }

        for (const res of run.results || []) {
            if (res.suppressions && res.suppressions.length > 0) continue;

            let level = res.level as string | undefined;
            if (!level && res.ruleId) {
                const rule = rulesMap.get(res.ruleId);
                level = rule?.defaultConfiguration?.level || 'warning';
            }

            if (level === 'none') continue;
            const normalizedLevel: 'error' | 'warning' | 'note' =
                level === 'error' ? 'error' : level === 'note' ? 'note' : 'warning';
            counts[normalizedLevel]++;

            const location = res.locations?.[0]?.physicalLocation;
            const fileUri = location?.artifactLocation?.uri || 'unknown';
            const line = location?.region?.startLine || 1;
            const message = res.message?.text || 'No description provided';

            findings.push({
                ruleId: res.ruleId || 'Rule',
                level: normalizedLevel,
                file: fileUri,
                line,
                message: message.replace(/\r?\n|\r/g, ' ').slice(0, 150)
            });
        }
    }

    const total = counts.error + counts.warning + counts.note;
    const badgeColor = counts.error > 0 ? 'red' : counts.warning > 0 ? 'yellow' : 'brightgreen';
    const badgeUrl = `https://img.shields.io/badge/${encodeURIComponent(badgeLabel)}-${total}_issues-${badgeColor}`;

    let md = `<!-- security-report-${commentTag} -->\n`;
    md += `### ${title}: ${total === 0 ? 'Passed ✅' : `${total} issue${total === 1 ? '' : 's'} detected ⚠️`}\n\n`;
    md += `![${badgeLabel}](${badgeUrl})\n\n`;
    md += `| Severity | Count |\n| :--- | :--- |\n`;
    md += `| 🔴 Error / High | ${counts.error} |\n`;
    md += `| 🟡 Warning / Medium | ${counts.warning} |\n`;
    md += `| 🟢 Note / Low | ${counts.note} |\n`;
    md += `| **Total** | **${total}** |\n\n`;

    if (total === 0) {
        md += `> ✅ No security vulnerabilities or policy violations detected.\n`;
    } else {
        const maxDisplay = 25;
        const displayed = findings.slice(0, maxDisplay);
        md += `<details>\n<summary><b>View Findings (${displayed.length}${total > maxDisplay ? ` of ${total}` : ''})</b></summary>\n\n`;
        md += `| Severity | Location | Rule | Description |\n| :--- | :--- | :--- | :--- |\n`;

        for (const f of displayed) {
            const icon = f.level === 'error' ? '🔴 Error' : f.level === 'note' ? '🟢 Note' : '🟡 Warning';
            md += `| ${icon} | \`${escapeTableCell(f.file)}:${f.line}\` | \`${escapeTableCell(f.ruleId)}\` | ${escapeTableCell(f.message)} |\n`;
        }

        if (total > maxDisplay) {
            md += `\n*...and ${total - maxDisplay} more findings. Check the attached artifact for the full report.*\n`;
        }
        md += `\n</details>\n`;
    }

    md += `\n*Last updated: ${new Date().toISOString()}*\n`;

    const reportFile = path.resolve(process.cwd(), `${commentTag}-summary.md`);
    fs.writeFileSync(reportFile, md, 'utf8');

    await core.summary.addRaw(md).write();
    core.setOutput('total-findings', total);
    core.setOutput('report-file', reportFile);

    const repo = process.env.GITHUB_REPOSITORY;
    const headers = {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github+json',
        'User-Agent': 'github-actions-security-report',
        'X-GitHub-Api-Version': '2022-11-28'
    };

    let prNumber: number | null = null;
    if (process.env.GITHUB_EVENT_PATH && fs.existsSync(process.env.GITHUB_EVENT_PATH)) {
        try {
            const eventData = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
            prNumber = eventData.pull_request?.number || eventData.issue?.number || null;
        } catch (err: unknown) {
            core.warning(`Could not read GITHUB_EVENT_PATH: ${err instanceof Error ? err.message : String(err)}. Skipping PR comment.`);
        }
    }

    if (prNumber && token && repo) {
        const marker = `<!-- security-report-${commentTag} -->`;
        const apiBase = `https://api.github.com/repos/${repo}`;
        try {
            const comments = await fetchAllComments(apiBase, prNumber, headers);
            const existing = comments.find((c) => c.body?.includes(marker));
            const url = existing ? `${apiBase}/issues/comments/${existing.id}` : `${apiBase}/issues/${prNumber}/comments`;
            const res = await fetch(url, {
                method: existing ? 'PATCH' : 'POST',
                headers: { ...headers, 'Content-Type': 'application/json' },
                body: JSON.stringify({ body: md })
            });
            if (res.ok) core.info(`${existing ? 'Updated' : 'Created'} PR comment on #${prNumber}`);
        } catch (err: unknown) {
            core.warning(`PR comment upsert failed: ${err instanceof Error ? err.message : String(err)}`);
        }
    }

    if (shouldManageIssue && token && repo) {
        const apiBase = `https://api.github.com/repos/${repo}`;
        const issueMarker = `<!-- issue-tag-${commentTag} -->`;
        try {
            const listRes = await fetch(`${apiBase}/issues?state=open&labels=automated-audit`, { headers });
            if (listRes.ok) {
                const issues = (await listRes.json()) as GitHubIssue[];
                const existingIssue = Array.isArray(issues) ? issues.find((i) => i.body?.includes(issueMarker)) : null;
                const runUrl = process.env.GITHUB_SERVER_URL && process.env.GITHUB_RUN_ID
                    ? `${process.env.GITHUB_SERVER_URL}/${repo}/actions/runs/${process.env.GITHUB_RUN_ID}`
                    : '';
                const body = `## Automated Security Audit Alert\n\n${issueMarker}\n${md}\n\n---\n*Run: [${process.env.GITHUB_RUN_ID || 'Workflow Run'}](${runUrl})*`;

                if (total > 0) {
                    if (existingIssue) {
                        await fetch(`${apiBase}/issues/${existingIssue.number}`, {
                            method: 'PATCH',
                            headers: { ...headers, 'Content-Type': 'application/json' },
                            body: JSON.stringify({ body })
                        });
                        core.info(`Updated open issue #${existingIssue.number}`);
                    } else {
                        const createRes = await fetch(`${apiBase}/issues`, {
                            method: 'POST',
                            headers: { ...headers, 'Content-Type': 'application/json' },
                            body: JSON.stringify({ title: issueTitle, body, labels: ['security', 'automated-audit'] })
                        });
                        if (createRes.ok) {
                            const created = (await createRes.json()) as GitHubIssue;
                            core.info(`Created new issue #${created.number}`);
                        }
                    }
                } else if (existingIssue) {
                    await fetch(`${apiBase}/issues/${existingIssue.number}/comments`, {
                        method: 'POST',
                        headers: { ...headers, 'Content-Type': 'application/json' },
                        body: JSON.stringify({ body: '✅ **Resolved**: The latest security scan detected 0 vulnerabilities. Closing issue.' })
                    });
                    await fetch(`${apiBase}/issues/${existingIssue.number}`, {
                        method: 'PATCH',
                        headers: { ...headers, 'Content-Type': 'application/json' },
                        body: JSON.stringify({ state: 'closed' })
                    });
                    core.info(`Closed resolved issue #${existingIssue.number}`);
                }
            }
        } catch (err: unknown) {
            core.warning(`Issue management failed: ${err instanceof Error ? err.message : String(err)}`);
        }
    }

    if (uploadArtifact && fs.existsSync(sarifPath)) {
        try {
            const artifact = new DefaultArtifactClient();
            const resolved = path.resolve(sarifPath);
            await artifact.uploadArtifact(
                `${commentTag}-report`,
                [resolved],
                path.dirname(resolved)
            );
            core.info(`Uploaded SARIF artifact: ${commentTag}-report`);
        } catch (err: unknown) {
            core.warning(`Artifact upload failed: ${err instanceof Error ? err.message : String(err)}`);
        }
    }

    if (failOnFindings && total > 0) {
        core.setFailed(`Failing build due to ${total} security finding(s).`);
    }
}

run().catch((err: unknown) => {
    core.setFailed(err instanceof Error ? err.message : String(err));
});
