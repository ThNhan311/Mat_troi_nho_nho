
class WorkoutHistoryData {
  // Lịch sử các buổi tập.
  static final List<Map<String, String>> history = [];

  // Trạng thái hoàn thành của từng bài tập.
  static final Map<String, bool> exerciseCompletion = {};

  static String _exerciseKey(String workoutTitle, String exerciseName) {
    return '$workoutTitle::$exerciseName';
  }

  static bool isExerciseCompleted(
      String workoutTitle,
      String exerciseName,
      ) {
    return exerciseCompletion[
    _exerciseKey(workoutTitle, exerciseName)
    ] ??
        false;
  }

  // Lưu trạng thái ngay khi người dùng tick hoặc bỏ tick.
  static void setExerciseCompleted({
    required String workoutTitle,
    required String exerciseName,
    required bool completed,
    required int completedCount,
    required int totalCount,
    required String duration,
  }) {
    exerciseCompletion[
    _exerciseKey(workoutTitle, exerciseName)
    ] = completed;

    // Chưa hoàn thành bài nào thì không ghi nhận buổi tập.
    if (completedCount == 0) {
      history.removeWhere(
            (item) => item['title'] == workoutTitle,
      );
      return;
    }

    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}';

    final existingIndex = history.indexWhere(
          (item) => item['title'] == workoutTitle,
    );

    final record = <String, String>{
      'date': date,
      'title': workoutTitle,
      'completed': '$completedCount/$totalCount bài tập',
      'duration': duration,
    };

    if (existingIndex >= 0) {
      history[existingIndex] = record;
    } else {
      history.insert(0, record);
    }
  }
}
