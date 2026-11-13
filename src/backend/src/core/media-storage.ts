import { mkdir, writeFile, readFile, rename, unlink, readdir, stat } from 'node:fs/promises';
import { join } from 'node:path';
export interface MediaStorage {
  write(name: string, data: Buffer): Promise<void>;
  commit(temp: string, final: string): Promise<void>;
  read(name: string): Promise<Buffer>;
  remove(name: string): Promise<void>;
  list(): Promise<{ name: string; modified: Date }[]>;
}
export class LocalMediaStorage implements MediaStorage {
  constructor(private root: string) {}
  private path(name: string) {
    if (!/^[a-f0-9-]{36}\.(webp|tmp)$/.test(name)) throw new Error('Invalid storage key');
    return join(this.root, name);
  }
  async write(name: string, data: Buffer) {
    await mkdir(this.root, { recursive: true, mode: 0o700 });
    await writeFile(this.path(name), data, { flag: 'wx', mode: 0o600 });
  }
  async commit(temp: string, final: string) {
    await rename(this.path(temp), this.path(final));
  }
  read(name: string) {
    return readFile(this.path(name));
  }
  async remove(name: string) {
    await unlink(this.path(name)).catch((e: NodeJS.ErrnoException) => {
      if (e.code !== 'ENOENT') throw e;
    });
  }
  async list() {
    await mkdir(this.root, { recursive: true, mode: 0o700 });
    const names = (await readdir(this.root)).filter((n) => /^[a-f0-9-]{36}\.(webp|tmp)$/.test(n));
    return Promise.all(
      names.map(async (name) => ({ name, modified: (await stat(this.path(name))).mtime })),
    );
  }
}
