import type { Dependencies } from '../../core/contracts.js';
import { MetricsRepository } from './repository.js';
export class MetricsService {
  constructor(private deps: Dependencies) {}
  async summary() {
    return {
      packages_saved: await new MetricsRepository(this.deps.db).packagesSaved(),
      definition: 'Paket yang telah diserahkan melalui validasi pickup.',
    };
  }
}
