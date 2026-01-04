// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSessionEntityCollection on Isar {
  IsarCollection<SessionEntity> get sessionEntitys => this.collection();
}

const SessionEntitySchema = CollectionSchema(
  name: r'SessionEntity',
  id: 7472964409236372477,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.long,
    ),
    r'lastMessageAt': PropertySchema(
      id: 1,
      name: r'lastMessageAt',
      type: IsarType.long,
    ),
    r'myOdid': PropertySchema(
      id: 2,
      name: r'myOdid',
      type: IsarType.string,
    ),
    r'myRatchetPrivateKey': PropertySchema(
      id: 3,
      name: r'myRatchetPrivateKey',
      type: IsarType.longList,
    ),
    r'myRatchetPublicKey': PropertySchema(
      id: 4,
      name: r'myRatchetPublicKey',
      type: IsarType.longList,
    ),
    r'previousSendingChainLength': PropertySchema(
      id: 5,
      name: r'previousSendingChainLength',
      type: IsarType.long,
    ),
    r'receivingChainKey': PropertySchema(
      id: 6,
      name: r'receivingChainKey',
      type: IsarType.string,
    ),
    r'receivingChainLength': PropertySchema(
      id: 7,
      name: r'receivingChainLength',
      type: IsarType.long,
    ),
    r'remoteDeviceId': PropertySchema(
      id: 8,
      name: r'remoteDeviceId',
      type: IsarType.string,
    ),
    r'remoteOdid': PropertySchema(
      id: 9,
      name: r'remoteOdid',
      type: IsarType.string,
    ),
    r'rootKey': PropertySchema(
      id: 10,
      name: r'rootKey',
      type: IsarType.longList,
    ),
    r'sendingChainKey': PropertySchema(
      id: 11,
      name: r'sendingChainKey',
      type: IsarType.string,
    ),
    r'sendingChainLength': PropertySchema(
      id: 12,
      name: r'sendingChainLength',
      type: IsarType.long,
    ),
    r'sessionId': PropertySchema(
      id: 13,
      name: r'sessionId',
      type: IsarType.string,
    ),
    r'skippedKeys': PropertySchema(
      id: 14,
      name: r'skippedKeys',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 15,
      name: r'status',
      type: IsarType.byte,
      enumMap: _SessionEntitystatusEnumValueMap,
    ),
    r'theirRatchetPublicKey': PropertySchema(
      id: 16,
      name: r'theirRatchetPublicKey',
      type: IsarType.longList,
    )
  },
  estimateSize: _sessionEntityEstimateSize,
  serialize: _sessionEntitySerialize,
  deserialize: _sessionEntityDeserialize,
  deserializeProp: _sessionEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'sessionId': IndexSchema(
      id: 6949518585047923839,
      name: r'sessionId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sessionId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'myOdid': IndexSchema(
      id: -4930129473854863582,
      name: r'myOdid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'myOdid',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'remoteOdid': IndexSchema(
      id: -4349081292464450490,
      name: r'remoteOdid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'remoteOdid',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _sessionEntityGetId,
  getLinks: _sessionEntityGetLinks,
  attach: _sessionEntityAttach,
  version: '3.1.0+1',
);

int _sessionEntityEstimateSize(
  SessionEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.myOdid.length * 3;
  {
    final value = object.myRatchetPrivateKey;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  {
    final value = object.myRatchetPublicKey;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  {
    final value = object.receivingChainKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.remoteDeviceId.length * 3;
  bytesCount += 3 + object.remoteOdid.length * 3;
  bytesCount += 3 + object.rootKey.length * 8;
  {
    final value = object.sendingChainKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sessionId.length * 3;
  bytesCount += 3 + object.skippedKeys.length * 3;
  {
    final value = object.theirRatchetPublicKey;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  return bytesCount;
}

void _sessionEntitySerialize(
  SessionEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.createdAt);
  writer.writeLong(offsets[1], object.lastMessageAt);
  writer.writeString(offsets[2], object.myOdid);
  writer.writeLongList(offsets[3], object.myRatchetPrivateKey);
  writer.writeLongList(offsets[4], object.myRatchetPublicKey);
  writer.writeLong(offsets[5], object.previousSendingChainLength);
  writer.writeString(offsets[6], object.receivingChainKey);
  writer.writeLong(offsets[7], object.receivingChainLength);
  writer.writeString(offsets[8], object.remoteDeviceId);
  writer.writeString(offsets[9], object.remoteOdid);
  writer.writeLongList(offsets[10], object.rootKey);
  writer.writeString(offsets[11], object.sendingChainKey);
  writer.writeLong(offsets[12], object.sendingChainLength);
  writer.writeString(offsets[13], object.sessionId);
  writer.writeString(offsets[14], object.skippedKeys);
  writer.writeByte(offsets[15], object.status.index);
  writer.writeLongList(offsets[16], object.theirRatchetPublicKey);
}

SessionEntity _sessionEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SessionEntity();
  object.createdAt = reader.readLong(offsets[0]);
  object.id = id;
  object.lastMessageAt = reader.readLongOrNull(offsets[1]);
  object.myOdid = reader.readString(offsets[2]);
  object.myRatchetPrivateKey = reader.readLongList(offsets[3]);
  object.myRatchetPublicKey = reader.readLongList(offsets[4]);
  object.previousSendingChainLength = reader.readLong(offsets[5]);
  object.receivingChainKey = reader.readStringOrNull(offsets[6]);
  object.receivingChainLength = reader.readLong(offsets[7]);
  object.remoteDeviceId = reader.readString(offsets[8]);
  object.remoteOdid = reader.readString(offsets[9]);
  object.rootKey = reader.readLongList(offsets[10]) ?? [];
  object.sendingChainKey = reader.readStringOrNull(offsets[11]);
  object.sendingChainLength = reader.readLong(offsets[12]);
  object.sessionId = reader.readString(offsets[13]);
  object.skippedKeys = reader.readString(offsets[14]);
  object.status =
      _SessionEntitystatusValueEnumMap[reader.readByteOrNull(offsets[15])] ??
          SessionStatus.active;
  object.theirRatchetPublicKey = reader.readLongList(offsets[16]);
  return object;
}

P _sessionEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLongList(offset)) as P;
    case 4:
      return (reader.readLongList(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLongList(offset) ?? []) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readLong(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (_SessionEntitystatusValueEnumMap[reader.readByteOrNull(offset)] ??
          SessionStatus.active) as P;
    case 16:
      return (reader.readLongList(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _SessionEntitystatusEnumValueMap = {
  'active': 0,
  'stale': 1,
  'closed': 2,
};
const _SessionEntitystatusValueEnumMap = {
  0: SessionStatus.active,
  1: SessionStatus.stale,
  2: SessionStatus.closed,
};

Id _sessionEntityGetId(SessionEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _sessionEntityGetLinks(SessionEntity object) {
  return [];
}

void _sessionEntityAttach(
    IsarCollection<dynamic> col, Id id, SessionEntity object) {
  object.id = id;
}

extension SessionEntityByIndex on IsarCollection<SessionEntity> {
  Future<SessionEntity?> getBySessionId(String sessionId) {
    return getByIndex(r'sessionId', [sessionId]);
  }

  SessionEntity? getBySessionIdSync(String sessionId) {
    return getByIndexSync(r'sessionId', [sessionId]);
  }

  Future<bool> deleteBySessionId(String sessionId) {
    return deleteByIndex(r'sessionId', [sessionId]);
  }

  bool deleteBySessionIdSync(String sessionId) {
    return deleteByIndexSync(r'sessionId', [sessionId]);
  }

  Future<List<SessionEntity?>> getAllBySessionId(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'sessionId', values);
  }

  List<SessionEntity?> getAllBySessionIdSync(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'sessionId', values);
  }

  Future<int> deleteAllBySessionId(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'sessionId', values);
  }

  int deleteAllBySessionIdSync(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'sessionId', values);
  }

  Future<Id> putBySessionId(SessionEntity object) {
    return putByIndex(r'sessionId', object);
  }

  Id putBySessionIdSync(SessionEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'sessionId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySessionId(List<SessionEntity> objects) {
    return putAllByIndex(r'sessionId', objects);
  }

  List<Id> putAllBySessionIdSync(List<SessionEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'sessionId', objects, saveLinks: saveLinks);
  }
}

extension SessionEntityQueryWhereSort
    on QueryBuilder<SessionEntity, SessionEntity, QWhere> {
  QueryBuilder<SessionEntity, SessionEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SessionEntityQueryWhere
    on QueryBuilder<SessionEntity, SessionEntity, QWhereClause> {
  QueryBuilder<SessionEntity, SessionEntity, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterWhereClause>
      sessionIdEqualTo(String sessionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sessionId',
        value: [sessionId],
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterWhereClause>
      sessionIdNotEqualTo(String sessionId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [],
              upper: [sessionId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [sessionId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [sessionId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [],
              upper: [sessionId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterWhereClause> myOdidEqualTo(
      String myOdid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'myOdid',
        value: [myOdid],
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterWhereClause>
      myOdidNotEqualTo(String myOdid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'myOdid',
              lower: [],
              upper: [myOdid],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'myOdid',
              lower: [myOdid],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'myOdid',
              lower: [myOdid],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'myOdid',
              lower: [],
              upper: [myOdid],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterWhereClause>
      remoteOdidEqualTo(String remoteOdid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'remoteOdid',
        value: [remoteOdid],
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterWhereClause>
      remoteOdidNotEqualTo(String remoteOdid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'remoteOdid',
              lower: [],
              upper: [remoteOdid],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'remoteOdid',
              lower: [remoteOdid],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'remoteOdid',
              lower: [remoteOdid],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'remoteOdid',
              lower: [],
              upper: [remoteOdid],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SessionEntityQueryFilter
    on QueryBuilder<SessionEntity, SessionEntity, QFilterCondition> {
  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      createdAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      createdAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      createdAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      createdAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      lastMessageAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastMessageAt',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      lastMessageAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastMessageAt',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      lastMessageAtEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastMessageAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      lastMessageAtGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastMessageAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      lastMessageAtLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastMessageAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      lastMessageAtBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastMessageAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myOdidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'myOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myOdidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'myOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myOdidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'myOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myOdidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'myOdid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myOdidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'myOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myOdidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'myOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myOdidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'myOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myOdidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'myOdid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myOdidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'myOdid',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myOdidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'myOdid',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'myRatchetPrivateKey',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'myRatchetPrivateKey',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'myRatchetPrivateKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'myRatchetPrivateKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'myRatchetPrivateKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'myRatchetPrivateKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPrivateKey',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPrivateKey',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPrivateKey',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPrivateKey',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPrivateKey',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPrivateKeyLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPrivateKey',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'myRatchetPublicKey',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'myRatchetPublicKey',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'myRatchetPublicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'myRatchetPublicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'myRatchetPublicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'myRatchetPublicKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPublicKey',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPublicKey',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPublicKey',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPublicKey',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPublicKey',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      myRatchetPublicKeyLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'myRatchetPublicKey',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      previousSendingChainLengthEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'previousSendingChainLength',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      previousSendingChainLengthGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'previousSendingChainLength',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      previousSendingChainLengthLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'previousSendingChainLength',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      previousSendingChainLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'previousSendingChainLength',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'receivingChainKey',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'receivingChainKey',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'receivingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'receivingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'receivingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'receivingChainKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'receivingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'receivingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'receivingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'receivingChainKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'receivingChainKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'receivingChainKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainLengthEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'receivingChainLength',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainLengthGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'receivingChainLength',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainLengthLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'receivingChainLength',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      receivingChainLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'receivingChainLength',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteDeviceIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remoteDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteDeviceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'remoteDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteDeviceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'remoteDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteDeviceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'remoteDeviceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteDeviceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'remoteDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteDeviceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'remoteDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteDeviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'remoteDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteDeviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'remoteDeviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteDeviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remoteDeviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteDeviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'remoteDeviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteOdidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remoteOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteOdidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'remoteOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteOdidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'remoteOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteOdidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'remoteOdid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteOdidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'remoteOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteOdidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'remoteOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteOdidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'remoteOdid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteOdidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'remoteOdid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteOdidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remoteOdid',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      remoteOdidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'remoteOdid',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      rootKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rootKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      rootKeyElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rootKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      rootKeyElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rootKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      rootKeyElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rootKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      rootKeyLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rootKey',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      rootKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rootKey',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      rootKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rootKey',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      rootKeyLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rootKey',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      rootKeyLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rootKey',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      rootKeyLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'rootKey',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sendingChainKey',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sendingChainKey',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sendingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sendingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sendingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sendingChainKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sendingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sendingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sendingChainKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sendingChainKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sendingChainKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sendingChainKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainLengthEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sendingChainLength',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainLengthGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sendingChainLength',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainLengthLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sendingChainLength',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sendingChainLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sendingChainLength',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sessionIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sessionIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sessionIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sessionIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sessionId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sessionIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sessionIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sessionIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sessionIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sessionId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sessionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      sessionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      skippedKeysEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'skippedKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      skippedKeysGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'skippedKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      skippedKeysLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'skippedKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      skippedKeysBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'skippedKeys',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      skippedKeysStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'skippedKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      skippedKeysEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'skippedKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      skippedKeysContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'skippedKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      skippedKeysMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'skippedKeys',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      skippedKeysIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'skippedKeys',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      skippedKeysIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'skippedKeys',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      statusEqualTo(SessionStatus value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      statusGreaterThan(
    SessionStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      statusLessThan(
    SessionStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      statusBetween(
    SessionStatus lower,
    SessionStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'theirRatchetPublicKey',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'theirRatchetPublicKey',
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'theirRatchetPublicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'theirRatchetPublicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'theirRatchetPublicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'theirRatchetPublicKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'theirRatchetPublicKey',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'theirRatchetPublicKey',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'theirRatchetPublicKey',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'theirRatchetPublicKey',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'theirRatchetPublicKey',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterFilterCondition>
      theirRatchetPublicKeyLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'theirRatchetPublicKey',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension SessionEntityQueryObject
    on QueryBuilder<SessionEntity, SessionEntity, QFilterCondition> {}

extension SessionEntityQueryLinks
    on QueryBuilder<SessionEntity, SessionEntity, QFilterCondition> {}

extension SessionEntityQuerySortBy
    on QueryBuilder<SessionEntity, SessionEntity, QSortBy> {
  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByLastMessageAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageAt', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByLastMessageAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageAt', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> sortByMyOdid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'myOdid', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> sortByMyOdidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'myOdid', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByPreviousSendingChainLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousSendingChainLength', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByPreviousSendingChainLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousSendingChainLength', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByReceivingChainKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receivingChainKey', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByReceivingChainKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receivingChainKey', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByReceivingChainLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receivingChainLength', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByReceivingChainLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receivingChainLength', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByRemoteDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteDeviceId', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByRemoteDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteDeviceId', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> sortByRemoteOdid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteOdid', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortByRemoteOdidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteOdid', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortBySendingChainKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendingChainKey', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortBySendingChainKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendingChainKey', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortBySendingChainLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendingChainLength', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortBySendingChainLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendingChainLength', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> sortBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> sortBySkippedKeys() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'skippedKeys', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      sortBySkippedKeysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'skippedKeys', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension SessionEntityQuerySortThenBy
    on QueryBuilder<SessionEntity, SessionEntity, QSortThenBy> {
  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByLastMessageAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageAt', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByLastMessageAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageAt', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> thenByMyOdid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'myOdid', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> thenByMyOdidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'myOdid', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByPreviousSendingChainLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousSendingChainLength', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByPreviousSendingChainLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousSendingChainLength', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByReceivingChainKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receivingChainKey', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByReceivingChainKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receivingChainKey', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByReceivingChainLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receivingChainLength', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByReceivingChainLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receivingChainLength', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByRemoteDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteDeviceId', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByRemoteDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteDeviceId', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> thenByRemoteOdid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteOdid', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenByRemoteOdidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteOdid', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenBySendingChainKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendingChainKey', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenBySendingChainKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendingChainKey', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenBySendingChainLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendingChainLength', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenBySendingChainLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sendingChainLength', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> thenBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> thenBySkippedKeys() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'skippedKeys', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy>
      thenBySkippedKeysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'skippedKeys', Sort.desc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension SessionEntityQueryWhereDistinct
    on QueryBuilder<SessionEntity, SessionEntity, QDistinct> {
  QueryBuilder<SessionEntity, SessionEntity, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct>
      distinctByLastMessageAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastMessageAt');
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct> distinctByMyOdid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'myOdid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct>
      distinctByMyRatchetPrivateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'myRatchetPrivateKey');
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct>
      distinctByMyRatchetPublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'myRatchetPublicKey');
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct>
      distinctByPreviousSendingChainLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'previousSendingChainLength');
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct>
      distinctByReceivingChainKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receivingChainKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct>
      distinctByReceivingChainLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receivingChainLength');
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct>
      distinctByRemoteDeviceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'remoteDeviceId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct> distinctByRemoteOdid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'remoteOdid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct> distinctByRootKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rootKey');
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct>
      distinctBySendingChainKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sendingChainKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct>
      distinctBySendingChainLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sendingChainLength');
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct> distinctBySessionId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct> distinctBySkippedKeys(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'skippedKeys', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct> distinctByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status');
    });
  }

  QueryBuilder<SessionEntity, SessionEntity, QDistinct>
      distinctByTheirRatchetPublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'theirRatchetPublicKey');
    });
  }
}

extension SessionEntityQueryProperty
    on QueryBuilder<SessionEntity, SessionEntity, QQueryProperty> {
  QueryBuilder<SessionEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SessionEntity, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SessionEntity, int?, QQueryOperations> lastMessageAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastMessageAt');
    });
  }

  QueryBuilder<SessionEntity, String, QQueryOperations> myOdidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'myOdid');
    });
  }

  QueryBuilder<SessionEntity, List<int>?, QQueryOperations>
      myRatchetPrivateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'myRatchetPrivateKey');
    });
  }

  QueryBuilder<SessionEntity, List<int>?, QQueryOperations>
      myRatchetPublicKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'myRatchetPublicKey');
    });
  }

  QueryBuilder<SessionEntity, int, QQueryOperations>
      previousSendingChainLengthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'previousSendingChainLength');
    });
  }

  QueryBuilder<SessionEntity, String?, QQueryOperations>
      receivingChainKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receivingChainKey');
    });
  }

  QueryBuilder<SessionEntity, int, QQueryOperations>
      receivingChainLengthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receivingChainLength');
    });
  }

  QueryBuilder<SessionEntity, String, QQueryOperations>
      remoteDeviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'remoteDeviceId');
    });
  }

  QueryBuilder<SessionEntity, String, QQueryOperations> remoteOdidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'remoteOdid');
    });
  }

  QueryBuilder<SessionEntity, List<int>, QQueryOperations> rootKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rootKey');
    });
  }

  QueryBuilder<SessionEntity, String?, QQueryOperations>
      sendingChainKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sendingChainKey');
    });
  }

  QueryBuilder<SessionEntity, int, QQueryOperations>
      sendingChainLengthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sendingChainLength');
    });
  }

  QueryBuilder<SessionEntity, String, QQueryOperations> sessionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionId');
    });
  }

  QueryBuilder<SessionEntity, String, QQueryOperations> skippedKeysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'skippedKeys');
    });
  }

  QueryBuilder<SessionEntity, SessionStatus, QQueryOperations>
      statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<SessionEntity, List<int>?, QQueryOperations>
      theirRatchetPublicKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'theirRatchetPublicKey');
    });
  }
}
