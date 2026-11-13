import { spawnSync } from 'node:child_process';
import { readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
const [group, filter] = process.argv.slice(2);
function walk(dir: string): string[] {
  return existsSync(dir)
    ? readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
        e.isDirectory()
          ? walk(join(dir, e.name))
          : e.name.endsWith('.test.ts')
            ? [join(dir, e.name)]
            : [],
      )
    : [];
}
const files = walk(group ? `test/${group}` : 'test').filter((f) => !filter || f.includes(filter));
if (!files.length) throw new Error('No matching tests');
const result = spawnSync(
  process.execPath,
  ['--import', 'tsx', '--test', '--test-concurrency=1', ...files],
  { stdio: 'inherit', env: process.env },
);
process.exit(result.status ?? 1);
