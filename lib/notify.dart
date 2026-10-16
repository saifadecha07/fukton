import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'content.dart';
import 'store.dart';
import 'theme.dart';
import 'version.dart';

final _plugin = FlutterLocalNotificationsPlugin();
const _reminderId = 1;

Future<void> initNotifications() async {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));
  await _plugin.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );
}

Future<bool> scheduleDaily(TimeOfDay t, String body) async {
  final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  final ok = await android?.requestNotificationsPermission() ?? true;
  if (!ok) return false;
  final now = tz.TZDateTime.now(tz.local);
  var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
  if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
  await _plugin.cancel(id: _reminderId);
  await _plugin.zonedSchedule(
    id: _reminderId,
    title: 'ถึงเวลากลับมาหาใจ',
    body: body,
    scheduledDate: at,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails('daily', 'เตือนให้ฝึกทุกวัน',
          channelDescription: 'เตือนวันละครั้ง ให้กลับมาฝึกสติ', importance: Importance.defaultImportance),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );
  return true;
}

Future<void> cancelDaily() => _plugin.cancel(id: _reminderId);

// ---- mindfulness bells during a class: silent, vibrate only ----
const _classBellBase = 100;
const _classBellMax = 16;

Future<bool> scheduleClassBells({required int everyMinutes, required int totalMinutes}) async {
  if (kIsWeb) return true;
  await cancelClassBells();
  if (everyMinutes <= 0) return true;
  final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  final ok = await android?.requestNotificationsPermission() ?? true;
  if (!ok) return false;
  final now = tz.TZDateTime.now(tz.local);
  var n = 0;
  for (var m = everyMinutes; m < totalMinutes && n < _classBellMax; m += everyMinutes, n++) {
    await _plugin.zonedSchedule(
      id: _classBellBase + n,
      title: 'ระฆังสติ',
      body: 'ตอนนี้ใจอยู่ในห้องไหม · ฟัง ดู จด',
      scheduledDate: now.add(Duration(minutes: m)),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails('classbell', 'ระฆังสติในห้องเรียน',
            channelDescription: 'สั่นเบา ๆ ระหว่างเรียน ให้กลับมาอยู่กับคาบ',
            importance: Importance.high,
            priority: Priority.high,
            playSound: false,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 180, 120, 180]),
            timeoutAfter: 20000),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
  return true;
}

Future<void> cancelClassBells() async {
  if (kIsWeb) return;
  for (var i = 0; i < _classBellMax; i++) {
    await _plugin.cancel(id: _classBellBase + i);
  }
}

// ---- study world: a nudge when each block of the life schedule begins ----
const _studyBellBase = 300;
const _studyBellMax = 60;

/// Replace all study-schedule reminders with [bells] (time, title, body).
Future<bool> scheduleStudyBells(List<(DateTime, String, String)> bells) async {
  if (kIsWeb) return true;
  await cancelStudyBells();
  final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  final ok = await android?.requestNotificationsPermission() ?? true;
  if (!ok) return false;
  final now = DateTime.now();
  var n = 0;
  for (final (at, title, body) in bells) {
    if (!at.isAfter(now) || n >= _studyBellMax) continue;
    await _plugin.zonedSchedule(
      id: _studyBellBase + n++,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('studyplan', 'ตารางอ่านหนังสือ',
            channelDescription: 'เตือนเมื่อถึงเวลารอบอ่าน ทวน และวางมือถือนอน', importance: Importance.high, priority: Priority.high),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
  return true;
}

Future<void> cancelStudyBells() async {
  if (kIsWeb) return;
  for (var i = 0; i < _studyBellMax; i++) {
    await _plugin.cancel(id: _studyBellBase + i);
  }
}

Future<void> openReminderSheet(BuildContext context, Store store) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReminderSheet(store),
    );

class _ReminderSheet extends StatefulWidget {
  final Store store;
  const _ReminderSheet(this.store);
  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late bool on = widget.store.prefs.getBool('remind-on') ?? false;
  late TimeOfDay time = TimeOfDay(
    hour: widget.store.prefs.getInt('remind-h') ?? 6,
    minute: widget.store.prefs.getInt('remind-m') ?? 0,
  );

  Future<void> _apply() async {
    final prefs = widget.store.prefs;
    await prefs.setBool('remind-on', on);
    await prefs.setInt('remind-h', time.hour);
    await prefs.setInt('remind-m', time.minute);
    if (on) {
      final ok = await scheduleDaily(time, creed[DateTime.now().day % creed.length].replaceAll('\n', ' '));
      if (!ok && mounted) {
        setState(() => on = false);
        await prefs.setBool('remind-on', false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยังไม่ได้อนุญาตการแจ้งเตือน เปิดได้ที่การตั้งค่าของโทรศัพท์')));
        }
      }
    } else {
      await cancelDaily();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final hh = time.hour.toString().padLeft(2, '0'), mm = time.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('ระฆังเตือนใจ', style: display(context, 21)),
        const SizedBox(height: 6),
        Text('ให้แอปเรียกเราวันละครั้ง ให้กลับมานั่งนิ่ง ๆ กับลมหายใจ', style: TextStyle(color: p.muted)),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: on,
          title: const Text('เตือนทุกวัน'),
          onChanged: (v) async {
            setState(() => on = v);
            await _apply();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: on,
          title: const Text('เวลา'),
          trailing: Text('$hh:$mm น.', style: display(context, 20)),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: time);
            if (t != null) {
              setState(() => time = t);
              await _apply();
            }
          },
        ),
        const SizedBox(height: 8),
        Text('เวอร์ชัน $appVersion (build $appBuild)', style: TextStyle(fontSize: 12, color: p.muted)),
      ]),
    );
  }
}
