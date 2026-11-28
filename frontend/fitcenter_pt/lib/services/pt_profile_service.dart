import 'api_client.dart';
import 'booking_models.dart';

/// What members read about this trainer. An empty field is an empty string.
class TrainerProfile {
  const TrainerProfile({
    this.bio = '',
    this.specialization = '',
    this.experienceSummary = '',
  });

  final String bio, specialization, experienceSummary;

  factory TrainerProfile.fromJson(Map<String, dynamic> value) {
    String field(String key) {
      final raw = value[key];
      if (raw == null) return '';
      return text(value, key);
    }

    // The id proves this is a profile and not some other answer.
    uuid(value, 'id');
    return TrainerProfile(
      bio: field('bio'),
      specialization: field('specialization'),
      experienceSummary: field('experienceSummary'),
    );
  }

  Map<String, String> toJson() => {
    'bio': bio,
    'specialization': specialization,
    'experienceSummary': experienceSummary,
  };
}

class PtProfileService {
  PtProfileService(this.api);

  final ApiClient api;

  Future<TrainerProfile> read() async =>
      TrainerProfile.fromJson(object(await api.request('GET', '/pt/profile')));

  Future<TrainerProfile> save(TrainerProfile profile) async {
    final payload = await api.request(
      'PUT',
      '/pt/profile',
      body: profile.toJson(),
    );
    try {
      return TrainerProfile.fromJson(object(payload));
    } catch (_) {
      throw const ApiError(
        200,
        'INVALID_RESPONSE',
        'Chưa xác nhận được kết quả lưu.',
        outcomeUnknown: true,
      );
    }
  }
}
