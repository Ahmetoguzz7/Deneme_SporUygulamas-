// ==========================================
// USER MODEL
// ==========================================
import 'package:flutter/src/material/dropdown.dart';

class Users {
  final String app;
  final String branches_id;
  final String first_name;
  final String last_name;
  final String email;
  final String phone;
  final String password_hash;
  final String role;
  final String profile_photo_url;
  final String amount;
  final String b_date;
  final String created_at;
  final String last_login;
  final String is_active;
  // 🔥 YENİ ALANLAR
  final String mother_name;
  final String mother_phone;
  final String father_name;
  final String father_phone;
  final String fcm_token;
  final String supervisor_coach_id;
  Users({
    required this.app,
    required this.branches_id,
    required this.first_name,
    required this.last_name,
    required this.email,
    required this.phone,
    required this.password_hash,
    required this.role,
    required this.profile_photo_url,
    required this.amount,
    required this.b_date,
    required this.created_at,
    required this.last_login,
    required this.is_active,
    this.mother_name = "",
    this.mother_phone = "",
    this.father_name = "",
    this.father_phone = "",
    this.fcm_token = "",
    this.supervisor_coach_id = '',
  });

  factory Users.fromJson(Map<String, dynamic> json) {
    return Users(
      app: json['app']?.toString() ?? '',
      branches_id: json['branches_id']?.toString() ?? '',
      first_name: json['first_name']?.toString() ?? '',
      last_name: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      password_hash: json['password_hash']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      profile_photo_url: json['profile_photo_url']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      b_date: json['b_date']?.toString() ?? '',
      created_at: json['created_at']?.toString() ?? '',
      last_login: json['last_login']?.toString() ?? '',
      is_active: json['is_active']?.toString() ?? '',
      mother_name: json['mother_name']?.toString() ?? '',
      mother_phone: json['mother_phone']?.toString() ?? '',
      father_name: json['father_name']?.toString() ?? '',
      father_phone: json['father_phone']?.toString() ?? '',
      fcm_token: json['fcm_token']?.toString() ?? '', // 🔥 BUNU EKLE
      supervisor_coach_id: json['supervisor_coach_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app': app,
      'branches_id': branches_id,
      'first_name': first_name,
      'last_name': last_name,
      'email': email,
      'phone': phone,
      'password_hash': password_hash,
      'role': role,
      'profile_photo_url': profile_photo_url,
      'amount': amount,
      'b_date': b_date,
      'created_at': created_at,
      'last_login': last_login,
      'is_active': is_active,
      'mother_name': mother_name,
      'mother_phone': mother_phone,
      'father_name': father_name,
      'father_phone': father_phone,
      'fcm_token': fcm_token,
      'supervisor_coach_id': supervisor_coach_id,
    };
  }
}

// ==========================================
// BRANCHES MODEL
// ==========================================
class Branches {
  final String branches_id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String is_active;
  final String created_at;

  Branches({
    required this.branches_id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.is_active,
    required this.created_at,
  });

  factory Branches.fromJson(Map<String, dynamic> json) {
    return Branches(
      branches_id: json['branches_id']?.toString() ?? '',
      name: json['branches_name']?.toString() ?? 'İsimsiz Şube',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      is_active: json['is_active']?.toString() ?? 'FALSE',
      created_at: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'branches_id': branches_id,
    'branches_name': name,
    'address': address,
    'phone': phone,
    'email': email,
    'is_active': is_active,
    'created_at': created_at,
  };
}

// ==========================================
// SPORTS MODEL
// ==========================================
class Sports {
  final String sports_id;
  final String name;
  final String description;

  Sports({
    required this.sports_id,
    required this.name,
    required this.description,
  });

  factory Sports.fromJson(Map<String, dynamic> json) {
    return Sports(
      sports_id: json['sports_id']?.toString() ?? '',
      name: json['spor_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'sports_id': sports_id,
    'spor_name': name,
    'description': description,
  };
}

// ==========================================
// COACH MODEL
// ==========================================
class Coach {
  final String coach_id;
  final String user_id;
  final String branches_id;
  final String sports_id;
  final String bio;
  final String certificate_info;
  final String monthly_salary;
  final String hired_at;
  final String supervisor_coach_id;

  Coach({
    required this.coach_id,
    required this.user_id,
    required this.branches_id,
    required this.sports_id,
    required this.bio,
    required this.certificate_info,
    required this.monthly_salary,
    required this.hired_at,
    this.supervisor_coach_id = '',
  });

  factory Coach.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> clean = {};
    json.forEach((k, v) {
      clean[k.toString().trim()] = v;
    });

    return Coach(
      coach_id: clean['coach_id']?.toString() ?? '',
      user_id: clean['user_id']?.toString() ?? '',
      branches_id: clean['branches_id']?.toString() ?? '',
      sports_id: clean['sports_id']?.toString() ?? '',
      bio: clean['bio']?.toString() ?? '',
      certificate_info: clean['certificate_info']?.toString() ?? '',
      monthly_salary: clean['monthly_salary']?.toString() ?? '0',
      hired_at: clean['hired_at']?.toString() ?? '',
      supervisor_coach_id: json['supervisor_coach_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'coach_id': coach_id,
    'user_id': user_id,
    'branches_id': branches_id,
    'sports_id': sports_id,
    'bio': bio,
    'certificate_info': certificate_info,
    'monthly_salary': monthly_salary,
    'hired_at': hired_at,
    'supervisor_coach_id': supervisor_coach_id,
  };
}

/*
// ==========================================
// GROUP MODEL (DÜZELTİLDİ)
// ==========================================
class Group {
  final String groups_id;
  final String branches_id;
  final String coach_id;
  final String sports_id;
  final String name;
  final String schedule;
  final String capacity;
  final String monthly_fee;
  final String is_active;

  Group({
    required this.groups_id,
    required this.branches_id,
    required this.coach_id,
    required this.sports_id,
    required this.name,
    required this.schedule,
    required this.capacity,
    required this.monthly_fee,
    required this.is_active,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    // 🔥 groups_name veya name'i al
    String groupName = json['groups_name']?.toString() ?? '';
    if (groupName.isEmpty) groupName = json['name']?.toString() ?? '';
    if (groupName.isEmpty) groupName = 'İsimsiz Grup';

    // 🔥 monthly_fee'i güvenli al
    String monthlyFeeStr = '0';
    final monthlyFeeRaw = json['monthly_fee'];
    if (monthlyFeeRaw != null && monthlyFeeRaw.toString().isNotEmpty) {
      monthlyFeeStr = monthlyFeeRaw.toString();
    }

    //print("📊 Group.fromJson: ${groupName} -> monthly_fee: '${monthlyFeeStr}'");

    return Group(
      groups_id: json['groups_id']?.toString() ?? '',
      branches_id: json['branches_id']?.toString() ?? '',
      coach_id: json['coach_id']?.toString() ?? '',
      sports_id: json['sports_id']?.toString() ?? '',
      name: groupName,
      schedule: json['schedule']?.toString() ?? '',
      capacity: json['capacity']?.toString() ?? '0',
      monthly_fee: monthlyFeeStr,
      is_active: json['is_active']?.toString() ?? 'FALSE',
    );
  }

  Map<String, dynamic> toJson() => {
    'groups_id': groups_id,
    'branches_id': branches_id,
    'coach_id': coach_id,
    'sports_id': sports_id,
    'groups_name': name,
    'schedule': schedule,
    'capacity': capacity,
    'monthly_fee': monthly_fee,
    'is_active': is_active,
  };
}
*/
// ==========================================
// GROUP MODEL (DÜZELTİLDİ - is_active eklendi)
// ==========================================
class Group {
  final String groups_id;
  final String branches_id;
  final String coach_id;
  final String sports_id;
  final String name;
  final String schedule;
  final String capacity;
  final String monthly_fee;
  final String is_active;

  Group({
    required this.groups_id,
    required this.branches_id,
    required this.coach_id,
    required this.sports_id,
    required this.name,
    required this.schedule,
    required this.capacity,
    required this.monthly_fee,
    required this.is_active,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    // 🔥 groups_name veya name'i al
    String groupName = json['groups_name']?.toString() ?? '';
    if (groupName.isEmpty) groupName = json['name']?.toString() ?? '';
    if (groupName.isEmpty) groupName = 'İsimsiz Grup';

    // 🔥 monthly_fee'i güvenli al
    String monthlyFeeStr = '0';
    final monthlyFeeRaw = json['monthly_fee'];
    if (monthlyFeeRaw != null && monthlyFeeRaw.toString().isNotEmpty) {
      monthlyFeeStr = monthlyFeeRaw.toString();
    }

    // 🔥🔥🔥 AKTİFLİK KONTROLÜ - DÜZELTİLDİ 🔥🔥🔥
    String isActiveStr = 'FALSE';
    final isActiveRaw = json['is_active'];
    if (isActiveRaw != null) {
      isActiveStr = isActiveRaw.toString().toUpperCase();
      // "1", "true", "TRUE" gibi değerleri "TRUE" yap
      if (isActiveStr == '1' || isActiveStr == 'TRUE' || isActiveStr == 'YES') {
        isActiveStr = 'TRUE';
      } else {
        isActiveStr = 'FALSE';
      }
    }

    // 🔥 DEBUG: Konsola yazdır
    // print("📊 Grup: $groupName, is_active: $isActiveStr");

    return Group(
      groups_id: json['groups_id']?.toString() ?? '',
      branches_id: json['branches_id']?.toString() ?? '',
      coach_id: json['coach_id']?.toString() ?? '',
      sports_id: json['sports_id']?.toString() ?? '',
      name: groupName,
      schedule: json['schedule']?.toString() ?? '',
      capacity: json['capacity']?.toString() ?? '0',
      monthly_fee: monthlyFeeStr,
      is_active: isActiveStr,
    );
  }

  Map<String, dynamic> toJson() => {
    'groups_id': groups_id,
    'branches_id': branches_id,
    'coach_id': coach_id,
    'sports_id': sports_id,
    'groups_name': name,
    'schedule': schedule,
    'capacity': capacity,
    'monthly_fee': monthly_fee,
    'is_active': is_active,
  };

  // 🔥 YARDIMCI METOT: Aktif mi?
  bool get isActive => is_active.toUpperCase() == 'TRUE';
}

// ==========================================
// GROUP STUDENT MODEL
// ==========================================
class GroupStudent {
  final String group_students_id;
  final String groups_id;
  final String student_id;
  final String enrolled_at;
  final String is_active;

  GroupStudent({
    required this.group_students_id,
    required this.groups_id,
    required this.student_id,
    required this.enrolled_at,
    required this.is_active,
  });

  factory GroupStudent.fromJson(Map<String, dynamic> json) {
    return GroupStudent(
      group_students_id: json['group_students_id']?.toString() ?? '',
      groups_id: json['groups_id']?.toString() ?? '',
      student_id: json['student_id']?.toString() ?? '',
      enrolled_at:
          json['enrolled_at']?.toString() ?? DateTime.now().toIso8601String(),
      is_active: json['is_active']?.toString() ?? 'TRUE',
    );
  }

  Map<String, dynamic> toJson() => {
    'group_students_id': group_students_id,
    'groups_id': groups_id,
    'student_id': student_id,
    'enrolled_at': enrolled_at,
    'is_active': is_active,
  };
}

// ==========================================
// ATTENDANCE MODEL
// ==========================================
class Attendance {
  final String attendances_id;
  final String groups_id;
  final String student_id;
  final String taken_by;
  final String attendance_date;
  final String status;
  final String note;
  final String updated_at;

  Attendance({
    required this.attendances_id,
    required this.groups_id,
    required this.student_id,
    required this.taken_by,
    required this.attendance_date,
    required this.status,
    required this.note,
    this.updated_at = '',
  });
  Attendance copyWith({
    String? attendances_id,
    String? groups_id,
    String? student_id,
    String? taken_by,
    String? attendance_date,
    String? status,
    String? note,
    String? updated_at,
  }) {
    return Attendance(
      attendances_id: attendances_id ?? this.attendances_id,
      groups_id: groups_id ?? this.groups_id,
      student_id: student_id ?? this.student_id,
      taken_by: taken_by ?? this.taken_by,
      attendance_date: attendance_date ?? this.attendance_date,
      status: status ?? this.status,
      note: note ?? this.note,
      updated_at: updated_at ?? this.updated_at,
    );
  }

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      attendances_id: json['attendances_id']?.toString() ?? '',
      groups_id: json['groups_id']?.toString() ?? '',
      student_id: json['student_id']?.toString() ?? '',
      taken_by: json['taken_by']?.toString() ?? '',
      attendance_date: json['attendance_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'FALSE',
      note: json['note']?.toString() ?? '',
      updated_at: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'attendances_id': attendances_id,
    'groups_id': groups_id,
    'student_id': student_id,
    'taken_by': taken_by,
    'attendance_date': attendance_date,
    'status': status,
    'note': note,
    'updated_at': updated_at,
  };
}

// ==========================================
// PAYMENT MODEL (DÜZELTİLDİ)
// ==========================================
class Payment {
  final String payments_id;
  final String student_id;
  final String groups_id;
  final String recorded_by;
  final String amount;
  final String due_date;
  final String paid_date;
  final String status;
  final String payment_method;
  final String note;

  Payment({
    required this.payments_id,
    required this.student_id,
    required this.groups_id,
    required this.recorded_by,
    required this.amount,
    required this.due_date,
    required this.paid_date,
    required this.status,
    required this.payment_method,
    required this.note,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    // 🔥 status dönüşümü: TRUE -> paid, FALSE/FALSE -> pending
    String statusValue = json['status']?.toString() ?? 'pending';
    if (statusValue.toUpperCase() == 'TRUE') {
      statusValue = 'paid';
    } else if (statusValue.toUpperCase() == 'FALSE') {
      statusValue = 'pending';
    }

    // 🔥 groups_id: group_id veya groups_id
    String groupsIdValue = json['groups_id']?.toString() ?? '';
    if (groupsIdValue.isEmpty) {
      groupsIdValue = json['group_id']?.toString() ?? '';
    }

    return Payment(
      payments_id: json['payments_id']?.toString() ?? '',
      student_id: json['student_id']?.toString() ?? '',
      groups_id: groupsIdValue,
      recorded_by: json['recorded_by']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      due_date: json['due_date']?.toString() ?? '',
      paid_date: json['paid_date']?.toString() ?? '',
      status: statusValue,
      payment_method: json['payment_method']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'payments_id': payments_id,
    'student_id': student_id,
    'group_id': groups_id,
    'recorded_by': recorded_by,
    'amount': amount,
    'due_date': due_date,
    'paid_date': paid_date,
    'status': status == 'paid' ? 'TRUE' : 'FALSE',
    'payment_method': payment_method,
    'note': note,
  };
}

// ==========================================
// NOTIFICATIONS MODEL
// ==========================================
class Notifications {
  final String notifications_id;
  final String sender_id;
  final String recipient_id;
  final String title;
  final String message;
  final String type;
  final String is_read;
  final String sent_at;
  final String groups_id;

  Notifications({
    required this.notifications_id,
    required this.sender_id,
    required this.recipient_id,
    required this.title,
    required this.message,
    required this.type,
    required this.is_read,
    required this.sent_at,
    required this.groups_id,
  });

  factory Notifications.fromJson(Map<String, dynamic> json) {
    return Notifications(
      notifications_id: json['notifications_id']?.toString() ?? '',
      sender_id: json['sender_id']?.toString() ?? '',
      recipient_id: json['recipient_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      is_read: json['is_read']?.toString() ?? 'FALSE',
      sent_at: json['sent_at']?.toString() ?? DateTime.now().toIso8601String(),
      groups_id: json['groups_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'notifications_id': notifications_id,
    'sender_id': sender_id,
    'recipient_id': recipient_id,
    'title': title,
    'message': message,
    'type': type,
    'is_read': is_read,
    'sent_at': sent_at,
    'groups_id': groups_id,
  };
}

// ==========================================
// PARENT STUDENT MODEL
// ==========================================
class ParentStudent {
  final String parent_student_id;
  final String parent_id;
  final String student_id;

  ParentStudent({
    required this.parent_student_id,
    required this.parent_id,
    required this.student_id,
  });

  factory ParentStudent.fromJson(Map<String, dynamic> json) {
    return ParentStudent(
      parent_student_id: json['parent_student_id']?.toString() ?? '',
      parent_id: json['parent_id']?.toString() ?? '',
      student_id: json['student_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'parent_student_id': parent_student_id,
    'parent_id': parent_id,
    'student_id': student_id,
  };
}

// ==========================================
// STUDENT NOTE MODEL
// ==========================================
class StudentNote {
  final String id;
  final String student_id;
  final String coach_id;
  final String note;
  final String created_at;

  StudentNote({
    required this.id,
    required this.student_id,
    required this.coach_id,
    required this.note,
    required this.created_at,
  });

  factory StudentNote.fromJson(Map<String, dynamic> json) {
    return StudentNote(
      id: json['id']?.toString() ?? '',
      student_id: json['student_id']?.toString() ?? '',
      coach_id: json['coach_id']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      created_at:
          json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': student_id,
    'coach_id': coach_id,
    'note': note,
    'created_at': created_at,
  };
}
