import 'json.dart';

enum Role { buyer, seller }

class User {
  final String id, email, name;
  final Role role;
  final List<String> allergenFilters;
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.allergenFilters,
  });
  factory User.fromJson(Json j) => User(
    id: text(j, 'id'),
    email: text(j, 'email'),
    name: text(j, 'name'),
    role: switch (text(j, 'role')) {
      'buyer' => Role.buyer,
      'seller' => Role.seller,
      _ => throw const FormatException('Role tidak valid.'),
    },
    allergenFilters: strings(j, 'allergen_filters'),
  );
  Json toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'role': role.name,
    'allergen_filters': allergenFilters,
  };
}

class SessionBundle {
  final String accessToken, refreshToken;
  final User user;
  final DateTime expiresAt;
  const SessionBundle({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.expiresAt,
  });
  factory SessionBundle.fromJson(Json j) => SessionBundle(
    accessToken: text(j, 'access_token'),
    refreshToken: text(j, 'refresh_token'),
    user: User.fromJson(jsonObject(j['user'])),
    expiresAt: instant(j, 'expires_at'),
  );
  Json toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'user': user.toJson(),
    'expires_at': expiresAt.toIso8601String(),
  };
  SessionBundle withUser(User next) => SessionBundle(
    accessToken: accessToken,
    refreshToken: refreshToken,
    user: next,
    expiresAt: expiresAt,
  );
}

class MerchantProfile {
  final String userId, name, address, bankMasked;
  final double? latitude, longitude;
  final String? photoId;
  const MerchantProfile({
    required this.userId,
    required this.name,
    required this.address,
    required this.bankMasked,
    this.latitude,
    this.longitude,
    this.photoId,
  });
  factory MerchantProfile.fromJson(Json j) => MerchantProfile(
    userId: text(j, 'user_id'),
    name: text(j, 'shop_name'),
    address: text(j, 'address'),
    bankMasked: text(j, 'bank_masked'),
    latitude: coordinate(j, 'latitude'),
    longitude: coordinate(j, 'longitude'),
    photoId: j['photo_id'] as String?,
  );
}
