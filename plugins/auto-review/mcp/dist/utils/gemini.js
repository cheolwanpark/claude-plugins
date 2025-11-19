import { spawn } from 'child_process';
/**
 * Read-only file exploration tools allowed for auto-approval during code reviews.
 * These tools enable gemini to analyze code without making modifications.
 */
const READ_ONLY_FILE_TOOLS = [
    'list_directory',
    'read_file',
    'glob',
    'search_file_content',
    'read_many_files',
];
/**
 * Spawns gemini-cli in headless mode and returns the JSON response
 */
export async function runGemini(prompt, cwd) {
    return new Promise((resolve, reject) => {
        const args = [
            prompt,
            '--output-format', 'json',
            '--allowed-tools', READ_ONLY_FILE_TOOLS.join(',')
        ];
        const gemini = spawn('gemini', args, {
            cwd: cwd || process.cwd(),
            stdio: ['ignore', 'pipe', 'pipe']
        });
        let stdout = '';
        let stderr = '';
        gemini.stdout.on('data', (data) => {
            stdout += data.toString();
        });
        gemini.stderr.on('data', (data) => {
            stderr += data.toString();
        });
        gemini.on('close', (code) => {
            if (code !== 0) {
                reject(new Error(`Gemini CLI exited with code ${code}: ${stderr}`));
                return;
            }
            try {
                const response = JSON.parse(stdout);
                resolve(response);
            }
            catch (error) {
                reject(new Error(`Failed to parse gemini response: ${error}`));
            }
        });
        gemini.on('error', (error) => {
            reject(new Error(`Failed to spawn gemini CLI: ${error.message}`));
        });
    });
}
//# sourceMappingURL=gemini.js.map