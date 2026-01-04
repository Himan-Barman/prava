// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sender_key_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSenderKeyEntityCollection on Isar {
  IsarCollection<SenderKeyEntity> get senderKeyEntitys => this.collection();
}

const SenderKeyEntitySchema = CollectionSchema(
  name: r'SenderKeyEntity',
  id: -1515637248649175098,
  properties: {
    r'chainKey': PropertySchema(
      id: 0,
      name: r'chainKey',
      type: IsarType.longList,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.long,
    ),
    r'deviceId': PropertySchema(
      id: 2,
      name: r'deviceId',
      type: IsarType.string,
    ),
    r'groupId': PropertySchema(
      id: 3,
      name: r'groupId',
      type: IsarType.string,
    ),
    r'groupSenderDevice': PropertySchema(
      id: 4,
      name: r'groupSenderDevice',
      type: IsarType.string,
    ),
    r'isOwn': PropertySchema(
      id: 5,
      name: r'isOwn',
      type: IsarType.bool,
    ),
    r'keyId': PropertySchema(
      id: 6,
      name: r'keyId',
      type: IsarType.long,
    ),
    r'lastUsedAt': PropertySchema(
      id: 7,
      name: r'lastUsedAt',
      type: IsarType.long,
    ),
    r'messageIndex': PropertySchema(
      id: 8,
      name: r'messageIndex',
      type: IsarType.long,
    ),
    r'senderId': PropertySchema(
      id: 9,
      name: r'senderId',
      type: IsarType.string,
    ),
    r'signaturePrivateKey': PropertySchema(
      id: 10,
      name: r'signaturePrivateKey',
      type: IsarType.longList,
    ),
    r'signaturePublicKey': PropertySchema(
      id: 11,
      name: r'signaturePublicKey',
      type: IsarType.longList,
    )
  },
  estimateSize: _senderKeyEntityEstimateSize,
  serialize: _senderKeyEntitySerialize,
  deserialize: _senderKeyEntityDeserialize,
  deserializeProp: _senderKeyEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'groupId': IndexSchema(
      id: -8523216633229774932,
      name: r'groupId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'groupId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'senderId': IndexSchema(
      id: -1619654757968658561,
      name: r'senderId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'senderId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'isOwn': IndexSchema(
      id: 6760454524508486645,
      name: r'isOwn',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isOwn',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'groupSenderDevice_senderId_deviceId': IndexSchema(
      id: -499507106905393824,
      name: r'groupSenderDevice_senderId_deviceId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'groupSenderDevice',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'senderId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'deviceId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _senderKeyEntityGetId,
  getLinks: _senderKeyEntityGetLinks,
  attach: _senderKeyEntityAttach,
  version: '3.1.0+1',
);

int _senderKeyEntityEstimateSize(
  SenderKeyEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.chainKey.length * 8;
  bytesCount += 3 + object.deviceId.length * 3;
  bytesCount += 3 + object.groupId.length * 3;
  bytesCount += 3 + object.groupSenderDevice.length * 3;
  bytesCount += 3 + object.senderId.length * 3;
  {
    final value = object.signaturePrivateKey;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  bytesCount += 3 + object.signaturePublicKey.length * 8;
  return bytesCount;
}

void _senderKeyEntitySerialize(
  SenderKeyEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLongList(offsets[0], object.chainKey);
  writer.writeLong(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.deviceId);
  writer.writeString(offsets[3], object.groupId);
  writer.writeString(offsets[4], object.groupSenderDevice);
  writer.writeBool(offsets[5], object.isOwn);
  writer.writeLong(offsets[6], object.keyId);
  writer.writeLong(offsets[7], object.lastUsedAt);
  writer.writeLong(offsets[8], object.messageIndex);
  writer.writeString(offsets[9], object.senderId);
  writer.writeLongList(offsets[10], object.signaturePrivateKey);
  writer.writeLongList(offsets[11], object.signaturePublicKey);
}

SenderKeyEntity _senderKeyEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SenderKeyEntity();
  object.chainKey = reader.readLongList(offsets[0]) ?? [];
  object.createdAt = reader.readLong(offsets[1]);
  object.deviceId = reader.readString(offsets[2]);
  object.groupId = reader.readString(offsets[3]);
  object.id = id;
  object.isOwn = reader.readBool(offsets[5]);
  object.keyId = reader.readLong(offsets[6]);
  object.lastUsedAt = reader.readLongOrNull(offsets[7]);
  object.messageIndex = reader.readLong(offsets[8]);
  object.senderId = reader.readString(offsets[9]);
  object.signaturePrivateKey = reader.readLongList(offsets[10]);
  object.signaturePublicKey = reader.readLongList(offsets[11]) ?? [];
  return object;
}

P _senderKeyEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongList(offset) ?? []) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readLongOrNull(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLongList(offset)) as P;
    case 11:
      return (reader.readLongList(offset) ?? []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _senderKeyEntityGetId(SenderKeyEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _senderKeyEntityGetLinks(SenderKeyEntity object) {
  return [];
}

void _senderKeyEntityAttach(
    IsarCollection<dynamic> col, Id id, SenderKeyEntity object) {
  object.id = id;
}

extension SenderKeyEntityQueryWhereSort
    on QueryBuilder<SenderKeyEntity, SenderKeyEntity, QWhere> {
  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhere> anyIsOwn() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isOwn'),
      );
    });
  }
}

extension SenderKeyEntityQueryWhere
    on QueryBuilder<SenderKeyEntity, SenderKeyEntity, QWhereClause> {
  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      idNotEqualTo(Id id) {
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

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause> idBetween(
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

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      groupIdEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'groupId',
        value: [groupId],
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      groupIdNotEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [],
              upper: [groupId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [groupId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [groupId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [],
              upper: [groupId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      senderIdEqualTo(String senderId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'senderId',
        value: [senderId],
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      senderIdNotEqualTo(String senderId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'senderId',
              lower: [],
              upper: [senderId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'senderId',
              lower: [senderId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'senderId',
              lower: [senderId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'senderId',
              lower: [],
              upper: [senderId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      isOwnEqualTo(bool isOwn) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isOwn',
        value: [isOwn],
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      isOwnNotEqualTo(bool isOwn) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isOwn',
              lower: [],
              upper: [isOwn],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isOwn',
              lower: [isOwn],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isOwn',
              lower: [isOwn],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isOwn',
              lower: [],
              upper: [isOwn],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      groupSenderDeviceEqualToAnySenderIdDeviceId(String groupSenderDevice) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'groupSenderDevice_senderId_deviceId',
        value: [groupSenderDevice],
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      groupSenderDeviceNotEqualToAnySenderIdDeviceId(String groupSenderDevice) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [],
              upper: [groupSenderDevice],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [groupSenderDevice],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [groupSenderDevice],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [],
              upper: [groupSenderDevice],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      groupSenderDeviceSenderIdEqualToAnyDeviceId(
          String groupSenderDevice, String senderId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'groupSenderDevice_senderId_deviceId',
        value: [groupSenderDevice, senderId],
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      groupSenderDeviceEqualToSenderIdNotEqualToAnyDeviceId(
          String groupSenderDevice, String senderId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [groupSenderDevice],
              upper: [groupSenderDevice, senderId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [groupSenderDevice, senderId],
              includeLower: false,
              upper: [groupSenderDevice],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [groupSenderDevice, senderId],
              includeLower: false,
              upper: [groupSenderDevice],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [groupSenderDevice],
              upper: [groupSenderDevice, senderId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      groupSenderDeviceSenderIdDeviceIdEqualTo(
          String groupSenderDevice, String senderId, String deviceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'groupSenderDevice_senderId_deviceId',
        value: [groupSenderDevice, senderId, deviceId],
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterWhereClause>
      groupSenderDeviceSenderIdEqualToDeviceIdNotEqualTo(
          String groupSenderDevice, String senderId, String deviceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [groupSenderDevice, senderId],
              upper: [groupSenderDevice, senderId, deviceId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [groupSenderDevice, senderId, deviceId],
              includeLower: false,
              upper: [groupSenderDevice, senderId],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [groupSenderDevice, senderId, deviceId],
              includeLower: false,
              upper: [groupSenderDevice, senderId],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupSenderDevice_senderId_deviceId',
              lower: [groupSenderDevice, senderId],
              upper: [groupSenderDevice, senderId, deviceId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SenderKeyEntityQueryFilter
    on QueryBuilder<SenderKeyEntity, SenderKeyEntity, QFilterCondition> {
  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      chainKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chainKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      chainKeyElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chainKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      chainKeyElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chainKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      chainKeyElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chainKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      chainKeyLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'chainKey',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      chainKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'chainKey',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      chainKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'chainKey',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      chainKeyLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'chainKey',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      chainKeyLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'chainKey',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      chainKeyLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'chainKey',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      createdAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      deviceIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      deviceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      deviceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      deviceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deviceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      deviceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      deviceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      deviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      deviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      deviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      deviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'groupId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'groupId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupSenderDeviceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupSenderDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupSenderDeviceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'groupSenderDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupSenderDeviceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'groupSenderDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupSenderDeviceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'groupSenderDevice',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupSenderDeviceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'groupSenderDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupSenderDeviceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'groupSenderDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupSenderDeviceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'groupSenderDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupSenderDeviceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'groupSenderDevice',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupSenderDeviceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupSenderDevice',
        value: '',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      groupSenderDeviceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'groupSenderDevice',
        value: '',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      idLessThan(
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

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      idBetween(
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

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      isOwnEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isOwn',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      keyIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'keyId',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      keyIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'keyId',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      keyIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'keyId',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      keyIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'keyId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      lastUsedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastUsedAt',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      lastUsedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastUsedAt',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      lastUsedAtEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUsedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      lastUsedAtGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUsedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      lastUsedAtLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUsedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      lastUsedAtBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUsedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      messageIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      messageIndexGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'messageIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      messageIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'messageIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      messageIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'messageIndex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      senderIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      senderIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      senderIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      senderIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'senderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      senderIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      senderIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      senderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      senderIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'senderId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      senderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'senderId',
        value: '',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      senderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'senderId',
        value: '',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'signaturePrivateKey',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'signaturePrivateKey',
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'signaturePrivateKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'signaturePrivateKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'signaturePrivateKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'signaturePrivateKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePrivateKey',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePrivateKey',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePrivateKey',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePrivateKey',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePrivateKey',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePrivateKeyLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePrivateKey',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePublicKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'signaturePublicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePublicKeyElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'signaturePublicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePublicKeyElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'signaturePublicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePublicKeyElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'signaturePublicKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePublicKeyLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePublicKey',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePublicKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePublicKey',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePublicKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePublicKey',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePublicKeyLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePublicKey',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePublicKeyLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePublicKey',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterFilterCondition>
      signaturePublicKeyLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signaturePublicKey',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension SenderKeyEntityQueryObject
    on QueryBuilder<SenderKeyEntity, SenderKeyEntity, QFilterCondition> {}

extension SenderKeyEntityQueryLinks
    on QueryBuilder<SenderKeyEntity, SenderKeyEntity, QFilterCondition> {}

extension SenderKeyEntityQuerySortBy
    on QueryBuilder<SenderKeyEntity, SenderKeyEntity, QSortBy> {
  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy> sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByGroupSenderDevice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupSenderDevice', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByGroupSenderDeviceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupSenderDevice', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy> sortByIsOwn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOwn', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByIsOwnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOwn', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy> sortByKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByKeyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByMessageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageIndex', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortByMessageIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageIndex', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortBySenderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      sortBySenderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.desc);
    });
  }
}

extension SenderKeyEntityQuerySortThenBy
    on QueryBuilder<SenderKeyEntity, SenderKeyEntity, QSortThenBy> {
  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy> thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByGroupSenderDevice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupSenderDevice', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByGroupSenderDeviceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupSenderDevice', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy> thenByIsOwn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOwn', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByIsOwnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOwn', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy> thenByKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByKeyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByMessageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageIndex', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenByMessageIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageIndex', Sort.desc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenBySenderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.asc);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QAfterSortBy>
      thenBySenderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.desc);
    });
  }
}

extension SenderKeyEntityQueryWhereDistinct
    on QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct> {
  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct>
      distinctByChainKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chainKey');
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct> distinctByDeviceId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct> distinctByGroupId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct>
      distinctByGroupSenderDevice({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupSenderDevice',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct> distinctByIsOwn() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isOwn');
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct> distinctByKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'keyId');
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct>
      distinctByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUsedAt');
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct>
      distinctByMessageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'messageIndex');
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct> distinctBySenderId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'senderId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct>
      distinctBySignaturePrivateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'signaturePrivateKey');
    });
  }

  QueryBuilder<SenderKeyEntity, SenderKeyEntity, QDistinct>
      distinctBySignaturePublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'signaturePublicKey');
    });
  }
}

extension SenderKeyEntityQueryProperty
    on QueryBuilder<SenderKeyEntity, SenderKeyEntity, QQueryProperty> {
  QueryBuilder<SenderKeyEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SenderKeyEntity, List<int>, QQueryOperations>
      chainKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chainKey');
    });
  }

  QueryBuilder<SenderKeyEntity, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SenderKeyEntity, String, QQueryOperations> deviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceId');
    });
  }

  QueryBuilder<SenderKeyEntity, String, QQueryOperations> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupId');
    });
  }

  QueryBuilder<SenderKeyEntity, String, QQueryOperations>
      groupSenderDeviceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupSenderDevice');
    });
  }

  QueryBuilder<SenderKeyEntity, bool, QQueryOperations> isOwnProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isOwn');
    });
  }

  QueryBuilder<SenderKeyEntity, int, QQueryOperations> keyIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'keyId');
    });
  }

  QueryBuilder<SenderKeyEntity, int?, QQueryOperations> lastUsedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUsedAt');
    });
  }

  QueryBuilder<SenderKeyEntity, int, QQueryOperations> messageIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'messageIndex');
    });
  }

  QueryBuilder<SenderKeyEntity, String, QQueryOperations> senderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'senderId');
    });
  }

  QueryBuilder<SenderKeyEntity, List<int>?, QQueryOperations>
      signaturePrivateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'signaturePrivateKey');
    });
  }

  QueryBuilder<SenderKeyEntity, List<int>, QQueryOperations>
      signaturePublicKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'signaturePublicKey');
    });
  }
}
