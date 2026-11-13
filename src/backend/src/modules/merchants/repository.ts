import type { Tx } from '../../core/contracts.js';
export type MerchantProfile = {
  user_id: string;
  shop_name: string;
  address: string;
  latitude: number | null;
  longitude: number | null;
  photo_id: string | null;
  bank_masked: string;
  updated_at: Date;
};
export class MerchantRepository {
  async update(
    tx: Tx,
    id: string,
    input: {
      shop_name: string;
      address: string;
      latitude: number;
      longitude: number;
      bank_masked?: string;
    },
    now: Date,
  ) {
    return (
      await tx.query<MerchantProfile>(
        'UPDATE merchant_profiles SET shop_name=$2,address=$3,latitude=$4,longitude=$5,bank_masked=COALESCE($6,bank_masked),updated_at=$7 WHERE user_id=$1 RETURNING *',
        [
          id,
          input.shop_name,
          input.address,
          input.latitude,
          input.longitude,
          input.bank_masked,
          now,
        ],
      )
    ).rows[0]!;
  }
}
