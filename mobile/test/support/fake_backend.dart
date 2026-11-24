import 'package:medrec/features/records/record_kind.dart';

import 'fake_server.dart';

/// An in-memory imitation of the MedRec API, just detailed enough for the
/// app's screens: accounts, the profile, record lists, the card and the
/// visitor log. It follows the real API's rules where the app depends on
/// them (status codes, messages, card normalisation, empty string clears).
class FakeBackend {
  FakeBackend() {
    _routes();
  }

  final server = FakeServer();

  /// Accounts by id. Each holds the user document plus its password.
  final _users = <String, Map<String, dynamic>>{};
  final _passwords = <String, String>{};
  final visitors = <String, List<Map<String, dynamic>>>{};
  var _nextId = 1;

  String _id(String prefix) => '$prefix${_nextId++}';

  /// Creates an account directly and returns its token.
  String addUser({
    required String name,
    required String email,
    String password = 'password1',
    Map<String, dynamic> extra = const {},
  }) {
    final id = _id('u');
    _users[id] = {
      '_id': id,
      'name': name,
      'alias': email.split('@').first,
      'email': email,
      for (final kind in recordKinds) kind.jsonKey: <Map<String, dynamic>>[],
      ...extra,
    };
    _passwords[id] = password;
    return tokenFor(id);
  }

  String tokenFor(String userId) => 'token-$userId';

  /// Makes every existing login token invalid, as if it expired.
  void expireAllTokens() => _revoked = true;
  bool _revoked = false;

  Map<String, dynamic> user(String email) =>
      _users.values.firstWhere((u) => u['email'] == email);

  Map<String, dynamic>? _caller(FakeRequest r) {
    final header = r.authorization ?? '';
    if (_revoked || !header.startsWith('Bearer token-')) return null;
    return _users[header.substring('Bearer token-'.length)];
  }

  static const _expired = Reply(401, {
    'message': 'Session expired. Please log in again.',
  });

  /// Wraps a route that needs a logged-in caller.
  Route _authed(Object? Function(FakeRequest r, Map<String, dynamic> me) fn) {
    return (r) {
      final me = _caller(r);
      return me == null ? _expired : fn(r, me);
    };
  }

  /// Copies values like the real API: "" and null clear, maps merge.
  static void _apply(Map<String, dynamic> target, Map<String, dynamic> body) {
    body.forEach((key, value) {
      if (value is Map) {
        final nested = Map<String, dynamic>.from(target[key] as Map? ?? {});
        _apply(nested, Map<String, dynamic>.from(value));
        target[key] = nested;
      } else if (value == null || value == '') {
        target.remove(key);
      } else {
        target[key] = value is String && num.tryParse(value) != null && key != 'phone_number'
            ? num.parse(value)
            : value;
      }
    });
  }

  void _routes() {
    server.on('POST', '/auth/signup', (r) {
      final body = r.json;
      final email = (body['email'] as String).trim().toLowerCase();
      if (_users.values.any((u) => u['email'] == email)) {
        return const Reply(409, {
          'message': 'An account with this email already exists.',
        });
      }
      final token = addUser(
        name: body['name'] as String,
        email: email,
        password: body['password'] as String,
      );
      final id = token.substring('token-'.length);
      _users[id]!['alias'] = body['alias'];
      return Reply(201, {'token': token, 'user': _users[id]});
    });

    server.on('POST', '/auth/login', (r) {
      final email = (r.json['email'] as String).trim().toLowerCase();
      final match = _users.values.where((u) => u['email'] == email);
      if (match.isEmpty || _passwords[match.first['_id']] != r.json['password']) {
        return const Reply(401, {'message': 'Invalid email or password.'});
      }
      _revoked = false;
      return {'token': tokenFor(match.first['_id'] as String), 'user': match.first};
    });

    server.on('GET', '/auth/me', _authed((r, me) => me));
    server.on('GET', '/me', _authed((r, me) => me));

    server.on(
      'PATCH',
      '/me/profile',
      _authed((r, me) {
        if (r.json['name'] is String && (r.json['name'] as String).trim().isEmpty) {
          return const Reply(400, {'message': 'Name cannot be empty.'});
        }
        _apply(me, r.json);
        return me;
      }),
    );

    server.on(
      'PUT',
      '/me/card',
      _authed((r, me) {
        final raw = r.json['card_Id'] as String? ?? '';
        if (raw.isEmpty) {
          me.remove('card_Id');
          return {'card_Id': null};
        }
        final card = raw.replaceAll(RegExp(r'[\s:-]'), '').toUpperCase();
        final taken = _users.values.any(
          (u) => u['card_Id'] == card && u['_id'] != me['_id'],
        );
        if (taken) {
          return const Reply(409, {
            'message': 'That card is already linked to another account.',
          });
        }
        me['card_Id'] = card;
        return {'card_Id': card};
      }),
    );

    server.on(
      'GET',
      '/me/visitors',
      _authed((r, me) => visitors[me['_id']] ?? const []),
    );

    List<Map<String, dynamic>>? listOf(Map<String, dynamic> me, String slug) {
      final kind = recordKinds.where((k) => k.slug == slug);
      if (kind.isEmpty) return null;
      return (me[kind.first.jsonKey] as List).cast<Map<String, dynamic>>();
    }

    server.on(
      'POST',
      '/me/:collection',
      _authed((r, me) {
        final list = listOf(me, r.params['collection']!);
        if (list == null) return const Reply(404, {'message': 'Not found'});
        final item = <String, dynamic>{'_id': _id('i')};
        _apply(item, r.json);
        list.add(item);
        return Reply(201, item);
      }),
    );

    server.on(
      'PUT',
      '/me/:collection/:id',
      _authed((r, me) {
        final list = listOf(me, r.params['collection']!) ?? const [];
        final item = list.where((i) => i['_id'] == r.params['id']);
        if (item.isEmpty) return const Reply(404, {'message': 'Not found'});
        _apply(item.first, r.json);
        return item.first;
      }),
    );

    server.on(
      'DELETE',
      '/me/:collection/:id',
      _authed((r, me) {
        final list = listOf(me, r.params['collection']!) ?? [];
        final before = list.length;
        list.removeWhere((i) => i['_id'] == r.params['id']);
        return list.length == before
            ? const Reply(404, {'message': 'Not found'})
            : {'message': 'Deleted'};
      }),
    );

    server.on('GET', '/reports', _authed((r, me) => const []));
  }
}
