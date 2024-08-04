import 'dart:convert';
import 'dart:io';

import 'package:checkngo/src/models/visitor.dart';
import 'package:checkngo/src/models/visitor_cache_model.dart';
import 'package:checkngo/src/utils/custom_exception.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class DBService {
  final Isar isar;
  DBService(this.isar) {
    // final list = [
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '0627987492',
    //     checkedInAt: DateTime(2024, 05, 21),
    //     visitReason: 'Something something',
    //   ),
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '0627987492',
    //     checkedInAt: DateTime.now(),
    //     checkedOutAt: DateTime.now(),
    //     visitReason: 'Something something',
    //   ),
    //
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '7627987492',
    //     checkedInAt: DateTime(2024, 05, 30),
    //     visitReason: 'Something something',
    //   ),
    //
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '1627077492',
    //     checkedInAt: DateTime(2024, 05, 13),
    //     visitReason: 'Something something',
    //   ),
    //
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '8647987492',
    //     checkedInAt: DateTime(2024, 05, 24),
    //     visitReason: 'Something something',
    //   ),
    //
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '9097987492',
    //     checkedInAt: DateTime(2024, 05, 15),
    //     visitReason: 'Something something',
    //   ),
    //
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '1644987492',
    //     checkedInAt: DateTime(2024, 05, 8),
    //     visitReason: 'Something something',
    //   ),
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '1644987492',
    //     checkedInAt: DateTime.now(),
    //     checkedOutAt: DateTime.now(),
    //     visitReason: 'Something something',
    //   ),
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '1627987492',
    //     checkedInAt: DateTime.now(),
    //     visitReason: 'Something something',
    //   ),
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '3627987292',
    //     checkedInAt: DateTime.now(),
    //     visitReason: 'Something something',
    //   ),
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '0627987493',
    //     checkedInAt: DateTime.now(),
    //     visitReason: 'Something something',
    //   ),
    //   Visitor(
    //     fullname: 'Jamiu Jimoh',
    //     phone: '0627987493',
    //     checkedInAt: DateTime.now(),
    //     checkedOutAt: DateTime.now(),
    //     visitReason: 'Something something',
    //   ),
    // ];
    // saveAll(list);
  }

  Future<void> saveAll(List<Visitor> visitors) async {
    await isar.writeTxn(() async {
      await isar.visitorCacheModels.putAll(
        List.generate(
          visitors.length,
          (i) {
            return VisitorCacheModel.fromVisitor(visitors[i]);
          },
        ),
      );
    });
  }

  Future<void> save(Visitor visitor) async {
    await isar.writeTxn(() async {
      await isar.visitorCacheModels.put(
        VisitorCacheModel.fromVisitor(visitor),
      );
    });
  }

  Future<Visitor> getVisitor(String phone) async {
    final found =
        await isar.visitorCacheModels.filter().phoneEqualTo(phone).findFirst();
    if (found == null) {
      throw CustomException(
          'Could not find the visitor with the given phone number');
    }

    return found.toVisitor();
  }

  Future<(List<Visitor>, bool)> getActiveVisitors() async {
    final count = await isar.visitorCacheModels.count();
    final found = await isar.visitorCacheModels
        .where()
        .filter()
        .checkedOutAtIsNull()
        .sortByCheckedInAtDesc()
        .findAll();

    final visitors = List.generate(found.length, (i) {
      return found[i].toVisitor();
    });
    return (visitors, count == 0);
  }

  Future<List<Visitor>> getVisitors(SortVisitorBy sort) async {
    final qBuilder = isar.visitorCacheModels.where();
    final list = await switch (sort) {
      SortVisitorBy.checkedIn => qBuilder.sortByCheckedInAtDesc().findAll(),
      SortVisitorBy.checkedOut => qBuilder
          .filter()
          .checkedOutAtIsNotNull()
          .sortByCheckedOutAtDesc()
          .findAll(),
    };
    return List.generate(list.length, (i) {
      return list[i].toVisitor();
    });
  }

  String toCSV(List<Visitor> visitors) {
    var csvData = [
      [
        'Full Name',
        'Phone Number',
        'Email',
        'Checked-in Time',
        'Checked-out Time',
        'Visit Reason'
      ], // Headers
      ...visitors.map((visitor) => visitor.toCsvRow()),
    ];
    return const ListToCsvConverter().convert(csvData);
  }

  Future<String?> getFilePath() async {
    await FilePicker.platform.clearTemporaryFiles();
    String? path = await FilePicker.platform.getDirectoryPath();
    return path;
  }

  Future<String?> saveCsvFile(List<Visitor> visitors) async {
    final directoryPath = await getFilePath();
    if (directoryPath == null) return null;

    final timestamp = DateTime.now().toIso8601String();
    final path = '$directoryPath/visitors_logs-$timestamp.csv';

    final file = File(path);
    final f = await file.writeAsString(toCSV(visitors));
    return f.path;
  }

  Future<String?> saveJsonFile(List<Visitor> visitors) async {
    final directoryPath = await getFilePath();
    if (directoryPath == null) return null;
    final timestamp = DateTime.now().toIso8601String();

    final path = '$directoryPath/visitors_logs-$timestamp.json';
    final file = File(path);

    final list = [];
    for (final visitor in visitors) {
      list.add(visitor.toMap());
    }

    final f = await file.writeAsString(json.encode(list));
    return f.path;
  }
}

enum SortVisitorBy { checkedIn, checkedOut }

enum FileSaveType { csv, json }
