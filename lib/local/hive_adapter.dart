import 'package:hive/hive.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';

// 📦 Hive Type ID'leri (her model için unique)
const int usersTypeId = 0;
const int groupsTypeId = 1;
const int groupStudentsTypeId = 2;
const int paymentsTypeId = 3;
const int attendancesTypeId = 4;
const int branchesTypeId = 5;
const int sportsTypeId = 6;
const int coachesTypeId = 7;
const int notificationsTypeId = 8;

// 🔥 Users için Hive Adapter
@HiveType(typeId: usersTypeId)
class HiveUsers {
  @HiveField(0)
  final List<Map<String, dynamic>> users;

  HiveUsers({required this.users});

  factory HiveUsers.fromUsers(List<Users> users) {
    return HiveUsers(users: users.map((u) => u.toJson()).toList());
  }

  List<Users> toUsers() {
    return users.map((json) => Users.fromJson(json)).toList();
  }
}

// 🔥 Groups için Hive Adapter
@HiveType(typeId: groupsTypeId)
class HiveGroups {
  @HiveField(0)
  final List<Map<String, dynamic>> groups;

  HiveGroups({required this.groups});

  factory HiveGroups.fromGroups(List<Group> groups) {
    return HiveGroups(groups: groups.map((g) => g.toJson()).toList());
  }

  List<Group> toGroups() {
    return groups.map((json) => Group.fromJson(json)).toList();
  }
}

// 🔥 GroupStudents için Hive Adapter
@HiveType(typeId: groupStudentsTypeId)
class HiveGroupStudents {
  @HiveField(0)
  final List<Map<String, dynamic>> groupStudents;

  HiveGroupStudents({required this.groupStudents});

  factory HiveGroupStudents.fromGroupStudents(List<GroupStudent> students) {
    return HiveGroupStudents(
      groupStudents: students.map((s) => s.toJson()).toList(),
    );
  }

  List<GroupStudent> toGroupStudents() {
    return groupStudents.map((json) => GroupStudent.fromJson(json)).toList();
  }
}

// 🔥 Payments için Hive Adapter
@HiveType(typeId: paymentsTypeId)
class HivePayments {
  @HiveField(0)
  final List<Map<String, dynamic>> payments;

  HivePayments({required this.payments});

  factory HivePayments.fromPayments(List<Payment> payments) {
    return HivePayments(payments: payments.map((p) => p.toJson()).toList());
  }

  List<Payment> toPayments() {
    return payments.map((json) => Payment.fromJson(json)).toList();
  }
}

// 🔥 Attendances için Hive Adapter
@HiveType(typeId: attendancesTypeId)
class HiveAttendances {
  @HiveField(0)
  final List<Map<String, dynamic>> attendances;

  HiveAttendances({required this.attendances});

  factory HiveAttendances.fromAttendances(List<Attendance> attendances) {
    return HiveAttendances(
      attendances: attendances.map((a) => a.toJson()).toList(),
    );
  }

  List<Attendance> toAttendances() {
    return attendances.map((json) => Attendance.fromJson(json)).toList();
  }
}

// 🔥 Coaches için Hive Adapter
@HiveType(typeId: coachesTypeId)
class HiveCoaches {
  @HiveField(0)
  final List<Map<String, dynamic>> coaches;

  HiveCoaches({required this.coaches});

  factory HiveCoaches.fromCoaches(List<Coach> coaches) {
    return HiveCoaches(coaches: coaches.map((c) => c.toJson()).toList());
  }

  List<Coach> toCoaches() {
    return coaches.map((json) => Coach.fromJson(json)).toList();
  }
}

// 🔥 Notifications için Hive Adapter
@HiveType(typeId: notificationsTypeId)
class HiveNotifications {
  @HiveField(0)
  final List<Map<String, dynamic>> notifications;

  HiveNotifications({required this.notifications});

  factory HiveNotifications.fromNotifications(
    List<Notifications> notifications,
  ) {
    return HiveNotifications(
      notifications: notifications.map((n) => n.toJson()).toList(),
    );
  }

  List<Notifications> toNotifications() {
    return notifications.map((json) => Notifications.fromJson(json)).toList();
  }
}
