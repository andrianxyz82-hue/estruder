import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_exam_app/features/splash/splash_screen.dart';
import 'package:safe_exam_app/features/auth/login_screen.dart';
import 'package:safe_exam_app/features/student/student_home_screen.dart';
import 'package:safe_exam_app/features/student/courses_screen.dart';
import 'package:safe_exam_app/features/student/exams_screen.dart';
import 'package:safe_exam_app/features/student/profile_screen.dart';
import 'package:safe_exam_app/features/teacher/teacher_dashboard_screen.dart';
import 'package:safe_exam_app/features/teacher/teacher_courses_screen.dart';
import 'package:safe_exam_app/features/teacher/teacher_exams_screen.dart';
import 'package:safe_exam_app/features/exam/exam_detail_screen.dart';
import 'package:safe_exam_app/features/student/course_detail_screen.dart';
import 'package:safe_exam_app/features/exam/exam_result_screen.dart';
import 'package:safe_exam_app/features/teacher/monitoring/monitoring_dashboard_screen.dart';
import 'package:safe_exam_app/features/teacher/monitoring/exam_results_list_screen.dart';
import 'package:safe_exam_app/features/student/widgets/custom_bottom_nav_bar.dart';
import 'package:safe_exam_app/features/teacher/cbt_url_screen.dart';
import 'package:safe_exam_app/features/exam/cbt_exam_screen.dart';
// Web preview removed - causes Android build error due to dart:html dependency

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),
      
      // Student Routes
      GoRoute(
        path: '/student/home',
        builder: (context, state) => const StudentBottomNav(),
      ),
      GoRoute(
        path: '/student/cbt-exam',
        builder: (context, state) => const CbtExamScreen(), // PRODUCTION: Full security features
      ),
      
      // Teacher Routes
      GoRoute(
        path: '/teacher/dashboard',
        builder: (context, state) => const TeacherBottomNav(),
      ),
      GoRoute(
        path: '/teacher/monitoring/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '0';
          final examData = state.extra as Map<String, dynamic>;
          return ExamResultsListScreen(examId: id, examData: examData);
        },
      ),
      GoRoute(
        path: '/teacher/cbt-settings',
        builder: (context, state) => const CbtUrlScreen(),
      ),
      
      // Exam Routes
      GoRoute(
        path: '/exam/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '0';
          return ExamDetailScreen(examId: id);
        },
      ),
      GoRoute(
        path: '/exam/result/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '0';
          return ExamResultScreen(examId: id);
        },
      ),
      GoRoute(
        path: '/course/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '0';
          return CourseDetailScreen(courseId: id);
        },
      ),
    ],
  );
}

// Student Bottom Navigation
class StudentBottomNav extends StatefulWidget {
  const StudentBottomNav({super.key});

  @override
  State<StudentBottomNav> createState() => _StudentBottomNavState();
}

class _StudentBottomNavState extends State<StudentBottomNav> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      StudentHomeScreen(
        onTabChange: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      const CoursesScreen(),
      const ExamsScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        icons: const [
          Icons.home_rounded,
          Icons.book_rounded,
          Icons.assignment_rounded,
          Icons.person_rounded,
        ],
      ),
    );
  }
}

// Teacher Bottom Navigation
class TeacherBottomNav extends StatefulWidget {
  const TeacherBottomNav({super.key});

  @override
  State<TeacherBottomNav> createState() => _TeacherBottomNavState();
}

class _TeacherBottomNavState extends State<TeacherBottomNav> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const TeacherDashboardScreen(),
    const TeacherCoursesScreen(),
    const TeacherExamsScreen(),
    const MonitoringDashboardScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        icons: const [
          Icons.dashboard_rounded,
          Icons.book_rounded,
          Icons.assignment_rounded,
          Icons.analytics_rounded,
          Icons.person_rounded,
        ],
      ),
    );
  }
}
