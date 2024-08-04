import 'package:intl/intl.dart';

extension Formatter on DateTime {
  String get daySuffix {
    if (day % 100 >= 11 && day % 100 <= 20) {
      return 'th';
    } else if (day % 10 == 1) {
      return 'st';
    } else if (day % 10 == 2) {
      return 'nd';
    } else if (day % 10 == 3) {
      return 'rd';
    } else {
      return 'th';
    }
  }

  String get timeMSuffix {
    if (hour >= 12) {
      return 'PM';
    } else {
      return 'AM';
    }
  }

  String get vDateFormat {
    final tempDay = DateFormat('dd').format(this) + daySuffix;
    final tempMonthYear = DateFormat('MMMM, yyyy').format(this);
    return '$tempDay $tempMonthYear';
  }

  String get vTimeFormat {
    final tempTime = DateFormat('hh:mm').format(this);
    return '$tempTime$timeMSuffix';
  }

  String get vDTFormat {
    return '$vDateFormat, $vTimeFormat';
  }
}
