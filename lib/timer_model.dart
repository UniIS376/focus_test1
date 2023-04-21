import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wakelock/wakelock.dart';

class TimerModel extends ChangeNotifier {
  static const String timerTask = "timerTask";
  Timer? _timer;
  int? _remainingTime = 0; // 남은 시간 변수
  int _rewards = 0; // 보상 변수
  bool _isPaused = false;

  int? get remainingTime => _remainingTime;

  int get rewards => _rewards; // 보상을 가져오는 getter

  bool get isPaused => _isPaused;
  bool _isMinuteCompleted = false; // 시간에 따른 보상 완료 변수

  void startTimer(int duration) {
    _remainingTime = duration;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime! > 0) {
        _remainingTime = _remainingTime! - 1;
        if (_remainingTime! % 60 == 0) {
          if (_isMinuteCompleted == false) {
            _rewards++;
            _isMinuteCompleted = true;
            notifyListeners();
          }
        } else {
          _isMinuteCompleted = false;
        }
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
    startBackgroundTask();
    Wakelock.enable();
    notifyListeners();
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _remainingTime = 0;
    _isPaused = false;
    stopBackgroundTask();
    Wakelock.disable();
    notifyListeners();
  }

  void pauseTimer() {
    _timer?.cancel();
    _timer = null;
    _isPaused = true;
    notifyListeners();
  }

  void resumeTimer() {
    if (_timer == null) {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_remainingTime! > 0) {
          _remainingTime = _remainingTime! - 1;
        } else {
          timer.cancel();
        }
        notifyListeners();
      });
    }
  }

  void startBackgroundTask() {
    // WorkManager (Android)
    Workmanager().registerOneOffTask(
      timerTask,
      timerTask,
      inputData: <String, dynamic>{'duration': _remainingTime},
      initialDelay: Duration(milliseconds: _remainingTime! * 1000),
    );
  }

  void stopBackgroundTask() {
    // WorkManager (Android)
    Workmanager().cancelByUniqueName(timerTask);
  }
}

class PomodoroModel extends ChangeNotifier {
  static const String timerTask = "timerTask";
  Timer? _timer;
  int? _remainingTime = 0; // 남은 시간 변수
  int _rewards = 0; // 보상 변수
  bool _isPaused = false;
  bool _isMinuteCompleted = false; // 시간에 따른 보상 완료 변수

  int _pomodoroTime = 1500; // 포모도로 타이머 시간(초)
  int _shortBreakTime = 300; // 짧은 휴식 시간(초)
  int _longBreakTime = 900; // 긴 휴식 시간(초)
  int _pomodorosCompleted = 0; // 완료된 포모도로 횟수
  int _totalPomodoros = 0; // 총 포모도로 횟수
  bool _isWorking = false; // 현재 포모도로가 진행 중인지 여부
  bool _isBreak = false; // 현재 포모도로가 휴식 중인지 여부

  int? get remainingTime => _remainingTime;
  int get rewards => _rewards;
  bool get isPaused => _isPaused;
  int get pomodoroTime => _pomodoroTime;
  int get shortBreakTime => _shortBreakTime;
  int get longBreakTime => _longBreakTime;
  int get pomodorosCompleted => _pomodorosCompleted;
  int get totalPomodoros => _totalPomodoros;
  bool get isWorking => _isWorking;
  bool get isBreak => _isBreak;

// 포모도로와 기존 타이머 기능을 통합한 startTimer() 메서드
  void startTimer({int? duration, bool usePomodoro = false}) {
    if (usePomodoro) {
      _remainingTime = _pomodoroTime;
      _startPomodoroTimer(_pomodoroTime, _shortBreakTime);
    } else {
      _remainingTime = duration;
      _startRegularTimer();
    }
    notifyListeners();
  }

  // 기존 타이머를 시작하는 메서드
  void _startRegularTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime! > 0) {
        _remainingTime = _remainingTime! - 1;
        if (_remainingTime! % 60 == 0) {
          if (_isMinuteCompleted == false) {
            _rewards++;
            _isMinuteCompleted = true;
            notifyListeners();
          }
        } else {
          _isMinuteCompleted = false;
        }
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
    startBackgroundTask();
    Wakelock.enable();
    notifyListeners();
  }

// 포모도로 타이머를 시작하는 메서드
  void _startPomodoroTimer(int workDuration, int breakDuration) {
    _isWorking = true;
    _isBreak = false;
    _totalPomodoros++;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime! > 0) {
        _remainingTime = _remainingTime! - 1;
        notifyListeners();
      } else {
        timer.cancel();

        if (_isWorking) {
          _remainingTime = breakDuration;
          _isWorking = false;
          _isBreak = true;
          _pomodorosCompleted++;
        } else {
          _remainingTime = workDuration;
          _isWorking = true;
          _isBreak = false;
        }

        _startPomodoroTimer(workDuration, breakDuration);
      }
    });

    startBackgroundTask();
    Wakelock.enable();
    notifyListeners();
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _remainingTime = 0;
    _isPaused = false;
    stopBackgroundTask();
    Wakelock.disable();
    notifyListeners();
  }

  void pauseTimer() {
    _timer?.cancel();
    _timer = null;
    _isPaused = true;
    notifyListeners();
  }

  void resumeTimer() {
    if (_timer == null) {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_remainingTime! > 0) {
          _remainingTime = _remainingTime! - 1;
        } else {
          timer.cancel();
        }
        notifyListeners();
      });
    }
  }

  void startBackgroundTask() {
// WorkManager (Android)
    Workmanager().registerOneOffTask(
      timerTask,
      timerTask,
      inputData: <String, dynamic>{'duration': _remainingTime},
      initialDelay: Duration(milliseconds: _remainingTime! * 1000),
    );
  }

  void stopBackgroundTask() {
// WorkManager (Android)
    Workmanager().cancelByUniqueName(timerTask);
  }

// 포모도로와 휴식이 모두 완료되었는지 확인하는 메서드
  bool isFinished() {
    return _pomodorosCompleted == _totalPomodoros;
  }
}
