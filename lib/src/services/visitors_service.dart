import 'package:checkngo/src/models/visitor.dart';
import 'package:checkngo/src/services/db_service.dart';
import 'package:checkngo/src/services/nfc_service.dart';
import 'package:checkngo/src/utils/custom_exception.dart';

class VisitorsService {
  final NFCService nfcService;
  final DBService dbService;

  const VisitorsService({required this.nfcService, required this.dbService});

  Future<Visitor> checkIn({
    required String name,
    required String phone,
    String email = '',
    String? visitReason,
  }) async {
    final visitor = Visitor(
      fullname: name,
      phone: phone,
      email: email.isEmpty ? null : email,
      checkedInAt: DateTime.now(),
      visitReason: visitReason,
    );

    try {
      // Write to the NFC tag and ensure this process completes before proceeding
      nfcService.startNFCOperation(
        nfcOperation: NFCOperation.write,
        data: phone,
      );

      // wait for 3 seconds at most, while app is waiting for user to provide nfc tag to read
      await Future.delayed(const Duration(seconds: 3));
      if (nfcService.isProcessing) {
        throw CustomException(
          'Trouble detecting an NFC tag. Bring tag close to device',
        );
      }
      if (nfcService.message.toLowerCase().contains('oops')) {
        throw CustomException(nfcService.message);
      }

      // Only after successful NFC write, save the visitor data to the local DB
      await dbService.save(visitor);
      return visitor;
    } catch (e) {
      rethrow;
    }
  }

  Future<Visitor> readNFC() async {
    // Get the visitor by reading from the NFC tag, set the checkedOutAt time
    try {
      nfcService.startNFCOperation(nfcOperation: NFCOperation.read);

      // wait for 3 seconds at most, while app is waiting for user to provide nfc tag to read
      await Future.delayed(const Duration(seconds: 3));
      if (nfcService.isProcessing) {
        throw CustomException(
          'Trouble detecting an NFC tag. Bring tag close to device',
        );
      }
      if (nfcService.message.toLowerCase().contains('oops')) {
        throw CustomException(nfcService.message);
      }

      final visitor = await dbService.getVisitor(nfcService.message);
      return visitor;
    } catch (e) {
      rethrow;
    }
  }

  Future<Visitor> checkOut(String phone) async {
    // save the data to the local DB
    try {
      final visitor = await dbService.getVisitor(phone);
      final updated = visitor.copyWith(checkedOutAt: DateTime.now());
      await dbService.save(updated);
      return visitor;
    } catch (e) {
      rethrow;
    }
  }

  Future<(List<Visitor>, bool)> getActiveVisitors() async {
    try {
      final visitors = await dbService.getActiveVisitors();
      return visitors;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> isEmptyList() async {
    try {
      final visitors = await getActiveVisitors();

      if (visitors.$1.isEmpty || visitors.$2) {
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Visitor>> getVisitors(SortVisitorBy sort) async {
    final visitors = await dbService.getVisitors(sort);
    return visitors;
  }
}
