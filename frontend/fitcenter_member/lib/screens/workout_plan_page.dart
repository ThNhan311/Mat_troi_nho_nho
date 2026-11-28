import 'package:flutter/material.dart';

import '../data/workout_history_data.dart';

class WorkoutPlanPage extends StatefulWidget {
  const WorkoutPlanPage({super.key});

  @override
  State<WorkoutPlanPage> createState() => _WorkoutPlanPageState();
}

class _WorkoutPlanPageState extends State<WorkoutPlanPage> {
  int selectedDay = 0;

  final List<Map<String, dynamic>> workoutDays = [
    {
      'day': 'Thứ 2',
      'title': 'Ngực & Tay sau',
      'duration': '60 phút',
      'exercises': [
        {'name': 'Barbell Bench Press', 'sets': '4 hiệp × 10 lần', 'note': 'Nghỉ 90 giây giữa các hiệp', 'completed': false},
        {'name': 'Incline Dumbbell Press', 'sets': '3 hiệp × 12 lần', 'note': 'Tập trung vào phần ngực trên', 'completed': false},
        {'name': 'Cable Fly', 'sets': '3 hiệp × 12 lần', 'note': 'Kiểm soát chuyển động', 'completed': false},
        {'name': 'Triceps Pushdown', 'sets': '3 hiệp × 12 lần', 'note': 'Giữ khuỷu tay cố định', 'completed': false},
      ],
    },
    {
      'day': 'Thứ 3',
      'title': 'Lưng & Tay trước',
      'duration': '60 phút',
      'exercises': [
        {'name': 'Lat Pulldown', 'sets': '4 hiệp × 10 lần', 'note': 'Kéo thanh xuống ngang ngực', 'completed': false},
        {'name': 'Seated Cable Row', 'sets': '3 hiệp × 12 lần', 'note': 'Giữ lưng thẳng', 'completed': false},
        {'name': 'Dumbbell Row', 'sets': '3 hiệp × 10 lần', 'note': 'Mỗi bên 10 lần', 'completed': false},
        {'name': 'Dumbbell Curl', 'sets': '3 hiệp × 12 lần', 'note': 'Không đung đưa người', 'completed': false},
      ],
    },
    {
      'day': 'Thứ 4',
      'title': 'Nghỉ',
      'duration': 'Recovery',
      'exercises': [],
    },
    {
      'day': 'Thứ 5',
      'title': 'Chân',
      'duration': '70 phút',
      'exercises': [
        {'name': 'Barbell Squat', 'sets': '4 hiệp × 10 lần', 'note': 'Giữ đầu gối ổn định', 'completed': false},
        {'name': 'Leg Press', 'sets': '3 hiệp × 12 lần', 'note': 'Không khóa đầu gối', 'completed': false},
        {'name': 'Leg Extension', 'sets': '3 hiệp × 12 lần', 'note': 'Thực hiện chậm và kiểm soát', 'completed': false},
        {'name': 'Leg Curl', 'sets': '3 hiệp × 12 lần', 'note': 'Tập trung vào cơ đùi sau', 'completed': false},
      ],
    },
    {
      'day': 'Thứ 6',
      'title': 'Vai & Core',
      'duration': '50 phút',
      'exercises': [
        {'name': 'Shoulder Press', 'sets': '4 hiệp × 10 lần', 'note': 'Không khóa khuỷu tay', 'completed': false},
        {'name': 'Lateral Raise', 'sets': '3 hiệp × 12 lần', 'note': 'Nâng đến ngang vai', 'completed': false},
        {'name': 'Front Raise', 'sets': '3 hiệp × 12 lần', 'note': 'Giữ thân người ổn định', 'completed': false},
        {'name': 'Plank', 'sets': '3 hiệp × 45 giây', 'note': 'Giữ cơ bụng siết chặt', 'completed': false},
      ],
    },
    {
      'day': 'Thứ 7',
      'title': 'Cardio',
      'duration': '40 phút',
      'exercises': [
        {'name': 'Treadmill', 'sets': '20 phút', 'note': 'Tốc độ vừa phải', 'completed': false},
        {'name': 'Cycling', 'sets': '10 phút', 'note': 'Duy trì nhịp ổn định', 'completed': false},
        {'name': 'Stretching', 'sets': '10 phút', 'note': 'Giãn cơ toàn thân', 'completed': false},
      ],
    },
    {
      'day': 'CN',
      'title': 'Nghỉ',
      'duration': 'Recovery',
      'exercises': [],
    },
  ];

  @override
  void initState() {
    super.initState();

    for (final day in workoutDays) {
      final title = day['title'] as String;
      final exercises = day['exercises'] as List<dynamic>;

      for (final item in exercises) {
        final exercise = item as Map<String, dynamic>;
        exercise['completed'] = WorkoutHistoryData.isExerciseCompleted(
          title,
          exercise['name'] as String,
        );
      }
    }
  }

  List<Map<String, dynamic>> get currentExercises {
    final exercises =
    workoutDays[selectedDay]['exercises'] as List<dynamic>;

    return exercises
        .map((exercise) => Map<String, dynamic>.from(exercise as Map))
        .toList();
  }

  int get completedCount {
    return currentExercises
        .where((exercise) => exercise['completed'] == true)
        .length;
  }

  void _toggleExercise(int index) {
    final exercises =
    workoutDays[selectedDay]['exercises'] as List<dynamic>;

    final exercise = exercises[index] as Map<String, dynamic>;
    final workoutTitle = workoutDays[selectedDay]['title'] as String;
    final duration = workoutDays[selectedDay]['duration'] as String;

    setState(() {
      exercise['completed'] = !(exercise['completed'] as bool);

      final completed = exercises.where(
            (item) => (item as Map<String, dynamic>)['completed'] == true,
      ).length;

      WorkoutHistoryData.setExerciseCompleted(
        workoutTitle: workoutTitle,
        exerciseName: exercise['name'] as String,
        completed: exercise['completed'] as bool,
        completedCount: completed,
        totalCount: exercises.length,
        duration: duration,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentDay = workoutDays[selectedDay];
    final exercises = currentDay['exercises'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kế hoạch tập luyện',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPlanHeader(context),
              const SizedBox(height: 20),
              _buildDaySelector(context),
              const SizedBox(height: 20),
              _buildWorkoutSummary(
                context,
                title: currentDay['title'] as String,
                duration: currentDay['duration'] as String,
                completed: completedCount,
                total: exercises.length,
              ),
              const SizedBox(height: 20),
              if (exercises.isEmpty)
                _buildRestDay(context)
              else
                ...List.generate(
                  exercises.length,
                      (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildExerciseCard(
                      context,
                      exercise: Map<String, dynamic>.from(
                        exercises[index] as Map,
                      ),
                      index: index,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.22),
            colors.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fitness_center, color: colors.primary, size: 34),
          const SizedBox(height: 14),
          Text(
            'Chương trình tập luyện',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kế hoạch được xây dựng bởi huấn luyện viên của bạn.',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: workoutDays.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = workoutDays[index];
          final isSelected = selectedDay == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedDay = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 68,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day['day'] as String,
                    style: TextStyle(
                      color: isSelected ? colors.onPrimary : colors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(
                    (day['exercises'] as List).isEmpty
                        ? Icons.hotel
                        : Icons.fitness_center,
                    size: 19,
                    color: isSelected ? colors.onPrimary : colors.primary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkoutSummary(
      BuildContext context, {
        required String title,
        required String duration,
        required int completed,
        required int total,
      }) {
    final colors = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.timer_outlined, color: colors.primary, size: 18),
              const SizedBox(width: 5),
              Text(
                duration,
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tiến độ',
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  '$completed/$total bài tập',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: colors.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
      BuildContext context, {
        required Map<String, dynamic> exercise,
        required int index,
      }) {
    final colors = Theme.of(context).colorScheme;
    final completed = exercise['completed'] as bool;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: completed
              ? colors.primary.withValues(alpha: 0.45)
              : colors.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _toggleExercise(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: completed ? colors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: completed
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.38),
                  width: 2,
                ),
              ),
              child: completed
                  ? Icon(Icons.check, size: 18, color: colors.onPrimary)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['name'] as String,
                  style: TextStyle(
                    color: colors.onSurface.withValues(
                      alpha: completed ? 0.54 : 1,
                    ),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration:
                    completed ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  exercise['sets'] as String,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  exercise['note'] as String,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.54),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestDay(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.hotel, size: 52, color: colors.primary),
          const SizedBox(height: 18),
          Text(
            'Ngày nghỉ',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy để cơ thể có thời gian phục hồi.\n'
                'Bạn có thể nghỉ ngơi hoặc vận động nhẹ.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}