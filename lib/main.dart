import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:async';
import 'timer_model.dart';
import 'background_tasks.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimerModel()),
        ChangeNotifierProvider(create: (_) => PomodoroModel()),

      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  TextEditingController _durationController =
      TextEditingController(); // 시간 입력 받는 변수
  GlobalKey<FormState> _formKey =
      GlobalKey<FormState>(); // Form 위젯의 상태를 검색하기 위한 GlobalKey
  bool _isPaused = false; // 일시정지 상태를 추적하는 새로운 상태 변수
  bool _notificationSent = false; // 알림이 전송되었는지 추적하는 새로운 상태 변수

  Timer? _timer; // 타이머 변수
  int? _remainingTime = 0; // 상태 변수


  // 초기 상태 설정을 위한 메서드
  // 생명주기 옵저버를 추가하고, 잠금 기능을 활성화하며, 알림을 초기화
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this); // 생명주기 옵저버 추가
    Wakelock.enable();
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _initializeNotifications();
  }

  // 클래스가 제거될 때 호출되는 메서드
  // 생명주기 옵저버를 제거
  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this); // 생명주기 옵저버 제거
    super.dispose();
  }

  // 앱의 생명주기 상태가 변경될 때 호출되는 메서드
  // 앱이 백그라운드로 전환되면 알림과 진동을 발생 시킴
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused && !_notificationSent) {
      // 앱이 백그라운드로 전환되면 알림이나 진동을 발생시킴
      _sendNotification(); // 알림 발생
      _vibrate(); // 진동 발생
      _notificationSent = true; // 알림 전송 상태를 true로 변경
    } else if (state == AppLifecycleState.resumed) {
      _notificationSent = false; // 앱이 다시 활성화되면 알림 전송 상태를 false로 변경
    }
  }

// 알림을 초기화하는 메서드
  Future<void> _initializeNotifications() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // 설정된 시간에 따라 알림을 보내는 메서드
  Future<void> _showNotification(int duration) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'timer_channel_id', 'timer_channel_name',
        channelDescription: 'timer_channel_description',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false);
    final platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        '집중 시간 종료',
        '지금부터 휴대폰을 사용할 수 있습니다.',
        tz.TZDateTime.now(tz.local).add(Duration(minutes: duration)),
        platformChannelSpecifics,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime);
  }

  // 앱이 백그라운드로 전환될 때 알림을 보내는 메서드
  Future<void> _sendNotification() async {
    if (_remainingTime! > 0) {
      // 남은 시간이 있는 경우에만 알림을 보냄
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'focus_notification_channel_id',
        '집중 알림',
        channelDescription: '앱이 백그라운드로 전환될 때 알림을 보냅니다.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        0,
        '집중 중입니다!',
        '다른 앱으로 전환하지 말고 집중하세요.',
        platformChannelSpecifics,
      );
    }
  }

  // 휴대폰을 잠그고, 알림을 보내고, 타이머를 시작하는 메서드
  void _lockPhone(int hours, int minutes, int seconds) {
    int totalSeconds = (hours * 3600) + (minutes * 60) + seconds; // 분을 초 단위로 변환
    Wakelock.disable();
    _showNotification(minutes);
    startBackgroundTask(totalSeconds);
    Workmanager().registerOneOffTask(
      "timerTask",
      simpleTaskKey,
      inputData: {'duration': totalSeconds},
    );
  }

  void startBackgroundTask(int duration) {
    // WorkManager (Android)
    Workmanager().registerOneOffTask(
      TimerModel.timerTask,
      TimerModel.timerTask,
      inputData: <String, dynamic>{'duration': duration},
      initialDelay: Duration(seconds: duration),
    );
  }

  // 타이머를 시작하는 메서드
  void _startTimer(int duration) {
    String input = _durationController.text;
    if (input.length < 6) {
      // 문자열 길이가 6보다 작은 경우
      int paddingCount = 6 - input.length;
      input = input.padLeft(input.length + paddingCount, '0'); // 앞에 0 추가하여 6자리로 만들어줌
    }
    int hours = int.parse(input.substring(0, 2));
    int minutes = int.parse(input.substring(2, 4));
    int seconds = int.parse(input.substring(4, 6));
    int totalSeconds = (hours * 3600) + (minutes * 60) + seconds;
    _lockPhone(hours, minutes, seconds);
    Provider.of<TimerModel>(context, listen: false).startTimer(totalSeconds);
    Provider.of<TimerModel>(context, listen: false).startBackgroundTask();
    Provider.of<TimerModel>(context, listen: false).stopBackgroundTask();

    Timer.periodic(Duration(minutes: 1), (timer) {
      _remainingTime = Provider.of<TimerModel>(context, listen: false).remainingTime;
      if (_remainingTime != null && _remainingTime! > 0) {
        setState(() {
          _remainingTime = _remainingTime! - 60;
        });
        Provider.of<TimerModel>(context, listen: false).rewards; // 보상 증가 함수 호출
      } else {
        timer.cancel();
      }
      _sendFocusCompletedNotification();
    });
  }


// 진동을 발생시키는 메서드
  void _vibrate() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(); // 진동 발생
    }
  }

  // 시간을 시, 분, 초로 나누어 문자열로 반환하는 메서드
  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    seconds = seconds % 3600;
    int minutes = seconds ~/ 60;
    seconds = seconds % 60;
    return '${hours.toString().padLeft(2, "0")}:${minutes.toString().padLeft(2, "0")}:${seconds.toString().padLeft(2, "0")}';
  }

  Future<void> _sendFocusCompletedNotification() async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'focus_completed_notification_channel_id',
      '집중 완료 알림',
      channelDescription: '집중 시간이 완료되면 알림을 보냅니다.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      '집중 시간 완료!',
      '수고하셨습니다. 집중 시간이 끝났습니다.',
      platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingTime = Provider.of<TimerModel>(context).remainingTime;
    return Scaffold(
      appBar: AppBar(
        title: Text('집중하기'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Form(
              key: _formKey,
              child: TextFormField(
                // 사용자의 입력을 받는 필드
                keyboardType: TextInputType.number, // 숫자 입력만 허용하도록 변경
                controller: _durationController,
                decoration: InputDecoration(
                  labelText: '집중 시간 설정 (예: 1시간 20분 22초 = 012022)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '시간을 입력하세요';
                  }
                  if (value.length != 6 ) {
                    return '올바른 시간 형식으로 입력하세요 (예: 012022)';
                  }
                  int? hours = int.tryParse(value.substring(0, 2));
                  int? minutes = int.tryParse(value.substring(2, 4));
                  int? seconds = int.tryParse(value.substring(4, 6));
                  if (hours == null || minutes == null || seconds == null) {
                    return '숫자만 입력하세요';
                  }
                  if (hours < 0 ||
                      hours > 23 ||
                      minutes < 0 ||
                      minutes > 59 ||
                      seconds < 0 ||
                      seconds > 59) {
                    return '올바른 시간 범위를 입력하세요';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              // 사용자의 집중 시간 입력을 받는 버튼 부분
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  String input = _durationController.text;
                  int hours = int.parse(input.substring(0, 2));
                  int minutes = int.parse(input.substring(2, 4));
                  int seconds = int.parse(input.substring(4, 6));
                  int totalSeconds = (hours * 3600) + (minutes * 60) + seconds;
                  _startTimer(totalSeconds);
                }
              },
              child: Text('집중 시작'),
            ),
            ElevatedButton(
              onPressed: remainingTime! > 0
                  ? () {
                setState(() {
                  if (_isPaused) {
                    Provider.of<TimerModel>(context, listen: false)
                        .resumeTimer();
                  } else {
                    Provider.of<TimerModel>(context, listen: false)
                        .pauseTimer();
                  }
                  _isPaused = !_isPaused;
                });
              }
                  : null,
              child: Text(_isPaused ? '다시 시작' : '일시정지'),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<TimerModel>(context, listen: false).cancelTimer();
                setState(() {
                  _isPaused = false;
                });
              },
              child: Text('전체 시간 취소'),
            ),
            SizedBox(height: 20),
            Text(
              '남은 시간: ${remainingTime != null ? _formatTime(remainingTime) : "00:00:00"}',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 20),
            Text(
              '획득한 보상: ${Provider.of<TimerModel>(context).rewards}',
              style: TextStyle(fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}