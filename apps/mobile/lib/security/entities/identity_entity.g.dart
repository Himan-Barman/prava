// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIdentityEntityCollection on Isar {
  IsarCollection<IdentityEntity> get identityEntitys => this.collection();
}

const IdentityEntitySchema = CollectionSchema(
  name: r'IdentityEntity',
  id: -1554072511367898456,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.long,
    ),
    r'deviceId': PropertySchema(
      id: 1,
      name: r'deviceId',
      type: IsarType.string,
    ),
    r'isLocal': PropertySchema(
      id: 2,
      name: r'isLocal',
      type: IsarType.bool,
    ),
    r'keyChangedAt': PropertySchema(
      id: 3,
      name: r'keyChangedAt',
      type: IsarType.long,
    ),
    r'odid': PropertySchema(
      id: 4,
      name: r'odid',
      type: IsarType.string,
    ),
    r'odidDevice': PropertySchema(
      id: 5,
      name: r'odidDevice',
      type: IsarType.string,
    ),
    r'privateKey': PropertySchema(
      id: 6,
      name: r'privateKey',
      type: IsarType.longList,
    ),
    r'publicKey': PropertySchema(
      id: 7,
      name: r'publicKey',
      type: IsarType.longList,
    ),
    r'registrationId': PropertySchema(
      id: 8,
      name: r'registrationId',
      type: IsarType.long,
    ),
    r'trustLevel': PropertySchema(
      id: 9,
      name: r'trustLevel',
      type: IsarType.byte,
      enumMap: _IdentityEntitytrustLevelEnumValueMap,
    ),
    r'verifiedAt': PropertySchema(
      id: 10,
      name: r'verifiedAt',
      type: IsarType.long,
    )
  },
  estimateSize: _identityEntityEstimateSize,
  serialize: _identityEntitySerialize,
  deserialize: _identityEntityDeserialize,
  deserializeProp: _identityEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'odid': IndexSchema(
      id: -5189628085132166738,
      name: r'odid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'odid',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'deviceId': IndexSchema(
      id: 4442814072367132509,
      name: r'deviceId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'deviceId',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'isLocal': IndexSchema(
      id: -2654459435177376306,
      name: r'isLocal',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isLocal',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'odidDevice_deviceId': IndexSchema(
      id: 2925098107383159010,
      name: r'odidDevice_deviceId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'odidDevice',
          type: IndexType.hash,
          caseSensitive: false,
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
  getId: _identityEntityGetId,
  getLinks: _identityEntityGetLinks,
  attach: _identityEntityAttach,
  version: '3.1.0+1',
);

int _identityEntityEstimateSize(
  IdentityEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.deviceId.length * 3;
  bytesCount += 3 + object.odid.length * 3;
  bytesCount += 3 + object.odidDevice.length * 3;
  {
    final value = object.privateKey;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  bytesCount += 3 + object.publicKey.length * 8;
  return bytesCount;
}

void _identityEntitySerialize(
  IdentityEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.deviceId);
  writer.writeBool(offsets[2], object.isLocal);
  writer.writeLong(offsets[3], object.keyChangedAt);
  writer.writeString(offsets[4], object.odid);
  writer.writeString(offsets[5], object.odidDevice);
  writer.writeLongList(offsets[6], object.privateKey);
  writer.writeLongList(offsets[7], object.publicKey);
  writer.writeLong(offsets[8], object.registrationId);
  writer.writeByte(offsets[9], object.trustLevel.index);
  writer.writeLong(offsets[10], object.verifiedAt);
}

IdentityEntity _identityEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IdentityEntity();
  object.createdAt = reader.readLong(offsets[0]);
  object.deviceId = reader.readString(offsets[1]);
  object.id = id;
  object.isLocal = reader.readBool(offsets[2]);
  object.keyChangedAt = reader.readLongOrNull(offsets[3]);
  object.odid = reader.readString(offsets[4]);
  object.privateKey = reader.readLongList(offsets[6]);
  object.publicKey = reader.readLongList(offsets[7]) ?? [];
  object.registrationId = reader.readLong(offsets[8]);
  object.trustLevel = _IdentityEntitytrustLevelValueEnumMap[
          reader.readByteOrNull(offsets[9])] ??
      TrustLevel.untrusted;
  object.verifiedAt = reader.readLongOrNull(offsets[10]);
  return object;
}

P _identityEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLongList(offset)) as P;
    case 7:
      return (reader.readLongList(offset) ?? []) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (_IdentityEntitytrustLevelValueEnumMap[
              reader.readByteOrNull(offset)] ??
          TrustLevel.untrusted) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _IdentityEntitytrustLevelEnumValueMap = {
  'untrusted': 0,
  'trusted': 1,
  'verified': 2,
  'blocked': 3,
};
const _IdentityEntitytrustLevelValueEnumMap = {
  0: TrustLevel.untrusted,
  1: TrustLevel.trusted,
  2: TrustLevel.verified,
  3: TrustLevel.blocked,
};

Id _identityEntityGetId(IdentityEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _identityEntityGetLinks(IdentityEntity object) {
  return [];
}

void _identityEntityAttach(
    IsarCollection<dynamic> col, Id id, IdentityEntity object) {
  object.id = id;
}

extension IdentityEntityByIndex on IsarCollection<IdentityEntity> {
  Future<IdentityEntity?> getByOdidDeviceDeviceId(
      String odidDevice, String deviceId) {
    return getByIndex(r'odidDevice_deviceId', [odidDevice, deviceId]);
  }

  IdentityEntity? getByOdidDeviceDeviceIdSync(
      String odidDevice, String deviceId) {
    return getByIndexSync(r'odidDevice_deviceId', [odidDevice, deviceId]);
  }

  Future<bool> deleteByOdidDeviceDeviceId(String odidDevice, String deviceId) {
    return deleteByIndex(r'odidDevice_deviceId', [odidDevice, deviceId]);
  }

  bool deleteByOdidDeviceDeviceIdSync(String odidDevice, String deviceId) {
    return deleteByIndexSync(r'odidDevice_deviceId', [odidDevice, deviceId]);
  }

  Future<List<IdentityEntity?>> getAllByOdidDeviceDeviceId(
      List<String> odidDeviceValues, List<String> deviceIdValues) {
    final len = odidDeviceValues.length;
    assert(deviceIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([odidDeviceValues[i], deviceIdValues[i]]);
    }

    return getAllByIndex(r'odidDevice_deviceId', values);
  }

  List<IdentityEntity?> getAllByOdidDeviceDeviceIdSync(
      List<String> odidDeviceValues, List<String> deviceIdValues) {
    final len = odidDeviceValues.length;
    assert(deviceIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([odidDeviceValues[i], deviceIdValues[i]]);
    }

    return getAllByIndexSync(r'odidDevice_deviceId', values);
  }

  Future<int> deleteAllByOdidDeviceDeviceId(
      List<String> odidDeviceValues, List<String> deviceIdValues) {
    final len = odidDeviceValues.length;
    assert(deviceIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([odidDeviceValues[i], deviceIdValues[i]]);
    }

    return deleteAllByIndex(r'odidDevice_deviceId', values);
  }

  int deleteAllByOdidDeviceDeviceIdSync(
      List<String> odidDeviceValues, List<String> deviceIdValues) {
    final len = odidDeviceValues.length;
    assert(deviceIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([odidDeviceValues[i], deviceIdValues[i]]);
    }

    return deleteAllByIndexSync(r'odidDevice_deviceId', values);
  }

  Future<Id> putByOdidDeviceDeviceId(IdentityEntity object) {
    return putByIndex(r'odidDevice_deviceId', object);
  }

  Id putByOdidDeviceDeviceIdSync(IdentityEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'odidDevice_deviceId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOdidDeviceDeviceId(List<IdentityEntity> objects) {
    return putAllByIndex(r'odidDevice_deviceId', objects);
  }

  List<Id> putAllByOdidDeviceDeviceIdSync(List<IdentityEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'odidDevice_deviceId', objects,
        saveLinks: saveLinks);
  }
}

extension IdentityEntityQueryWhereSort
    on QueryBuilder<IdentityEntity, IdentityEntity, QWhere> {
  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhere> anyIsLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isLocal'),
      );
    });
  }
}

extension IdentityEntityQueryWhere
    on QueryBuilder<IdentityEntity, IdentityEntity, QWhereClause> {
  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause> idBetween(
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause> odidEqualTo(
      String odid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'odid',
        value: [odid],
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause>
      odidNotEqualTo(String odid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odid',
              lower: [],
              upper: [odid],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odid',
              lower: [odid],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odid',
              lower: [odid],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odid',
              lower: [],
              upper: [odid],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause>
      deviceIdEqualTo(String deviceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'deviceId',
        value: [deviceId],
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause>
      deviceIdNotEqualTo(String deviceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deviceId',
              lower: [],
              upper: [deviceId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deviceId',
              lower: [deviceId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deviceId',
              lower: [deviceId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deviceId',
              lower: [],
              upper: [deviceId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause>
      isLocalEqualTo(bool isLocal) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isLocal',
        value: [isLocal],
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause>
      isLocalNotEqualTo(bool isLocal) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isLocal',
              lower: [],
              upper: [isLocal],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isLocal',
              lower: [isLocal],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isLocal',
              lower: [isLocal],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isLocal',
              lower: [],
              upper: [isLocal],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause>
      odidDeviceEqualToAnyDeviceId(String odidDevice) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'odidDevice_deviceId',
        value: [odidDevice],
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause>
      odidDeviceNotEqualToAnyDeviceId(String odidDevice) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odidDevice_deviceId',
              lower: [],
              upper: [odidDevice],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odidDevice_deviceId',
              lower: [odidDevice],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odidDevice_deviceId',
              lower: [odidDevice],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odidDevice_deviceId',
              lower: [],
              upper: [odidDevice],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause>
      odidDeviceDeviceIdEqualTo(String odidDevice, String deviceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'odidDevice_deviceId',
        value: [odidDevice, deviceId],
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterWhereClause>
      odidDeviceEqualToDeviceIdNotEqualTo(String odidDevice, String deviceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odidDevice_deviceId',
              lower: [odidDevice],
              upper: [odidDevice, deviceId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odidDevice_deviceId',
              lower: [odidDevice, deviceId],
              includeLower: false,
              upper: [odidDevice],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odidDevice_deviceId',
              lower: [odidDevice, deviceId],
              includeLower: false,
              upper: [odidDevice],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'odidDevice_deviceId',
              lower: [odidDevice],
              upper: [odidDevice, deviceId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension IdentityEntityQueryFilter
    on QueryBuilder<IdentityEntity, IdentityEntity, QFilterCondition> {
  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      createdAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      deviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      deviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      deviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      deviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition> idBetween(
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

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      isLocalEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isLocal',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      keyChangedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'keyChangedAt',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      keyChangedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'keyChangedAt',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      keyChangedAtEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'keyChangedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      keyChangedAtGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'keyChangedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      keyChangedAtLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'keyChangedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      keyChangedAtBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'keyChangedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'odid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'odid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'odid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'odid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'odid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'odid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'odid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'odid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'odid',
        value: '',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'odid',
        value: '',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidDeviceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'odidDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidDeviceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'odidDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidDeviceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'odidDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidDeviceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'odidDevice',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidDeviceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'odidDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidDeviceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'odidDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidDeviceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'odidDevice',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidDeviceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'odidDevice',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidDeviceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'odidDevice',
        value: '',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      odidDeviceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'odidDevice',
        value: '',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'privateKey',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'privateKey',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'privateKey',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'privateKey',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'privateKey',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'privateKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'privateKey',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'privateKey',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'privateKey',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'privateKey',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'privateKey',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      privateKeyLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'privateKey',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      publicKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      publicKeyElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'publicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      publicKeyElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'publicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      publicKeyElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'publicKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      publicKeyLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'publicKey',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      publicKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'publicKey',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      publicKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'publicKey',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      publicKeyLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'publicKey',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      publicKeyLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'publicKey',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      publicKeyLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'publicKey',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      registrationIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'registrationId',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      registrationIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'registrationId',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      registrationIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'registrationId',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      registrationIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'registrationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      trustLevelEqualTo(TrustLevel value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'trustLevel',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      trustLevelGreaterThan(
    TrustLevel value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'trustLevel',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      trustLevelLessThan(
    TrustLevel value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'trustLevel',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      trustLevelBetween(
    TrustLevel lower,
    TrustLevel upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'trustLevel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      verifiedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'verifiedAt',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      verifiedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'verifiedAt',
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      verifiedAtEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'verifiedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      verifiedAtGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'verifiedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      verifiedAtLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'verifiedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterFilterCondition>
      verifiedAtBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'verifiedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension IdentityEntityQueryObject
    on QueryBuilder<IdentityEntity, IdentityEntity, QFilterCondition> {}

extension IdentityEntityQueryLinks
    on QueryBuilder<IdentityEntity, IdentityEntity, QFilterCondition> {}

extension IdentityEntityQuerySortBy
    on QueryBuilder<IdentityEntity, IdentityEntity, QSortBy> {
  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> sortByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> sortByIsLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocal', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByIsLocalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocal', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByKeyChangedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyChangedAt', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByKeyChangedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyChangedAt', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> sortByOdid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'odid', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> sortByOdidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'odid', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByOdidDevice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'odidDevice', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByOdidDeviceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'odidDevice', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByRegistrationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'registrationId', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByRegistrationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'registrationId', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByTrustLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trustLevel', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByTrustLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trustLevel', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByVerifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'verifiedAt', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      sortByVerifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'verifiedAt', Sort.desc);
    });
  }
}

extension IdentityEntityQuerySortThenBy
    on QueryBuilder<IdentityEntity, IdentityEntity, QSortThenBy> {
  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> thenByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> thenByIsLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocal', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByIsLocalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocal', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByKeyChangedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyChangedAt', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByKeyChangedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyChangedAt', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> thenByOdid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'odid', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy> thenByOdidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'odid', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByOdidDevice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'odidDevice', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByOdidDeviceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'odidDevice', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByRegistrationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'registrationId', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByRegistrationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'registrationId', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByTrustLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trustLevel', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByTrustLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trustLevel', Sort.desc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByVerifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'verifiedAt', Sort.asc);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QAfterSortBy>
      thenByVerifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'verifiedAt', Sort.desc);
    });
  }
}

extension IdentityEntityQueryWhereDistinct
    on QueryBuilder<IdentityEntity, IdentityEntity, QDistinct> {
  QueryBuilder<IdentityEntity, IdentityEntity, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QDistinct> distinctByDeviceId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QDistinct> distinctByIsLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isLocal');
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QDistinct>
      distinctByKeyChangedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'keyChangedAt');
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QDistinct> distinctByOdid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'odid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QDistinct> distinctByOdidDevice(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'odidDevice', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QDistinct>
      distinctByPrivateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'privateKey');
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QDistinct>
      distinctByPublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publicKey');
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QDistinct>
      distinctByRegistrationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'registrationId');
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QDistinct>
      distinctByTrustLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trustLevel');
    });
  }

  QueryBuilder<IdentityEntity, IdentityEntity, QDistinct>
      distinctByVerifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'verifiedAt');
    });
  }
}

extension IdentityEntityQueryProperty
    on QueryBuilder<IdentityEntity, IdentityEntity, QQueryProperty> {
  QueryBuilder<IdentityEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IdentityEntity, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<IdentityEntity, String, QQueryOperations> deviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceId');
    });
  }

  QueryBuilder<IdentityEntity, bool, QQueryOperations> isLocalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isLocal');
    });
  }

  QueryBuilder<IdentityEntity, int?, QQueryOperations> keyChangedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'keyChangedAt');
    });
  }

  QueryBuilder<IdentityEntity, String, QQueryOperations> odidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'odid');
    });
  }

  QueryBuilder<IdentityEntity, String, QQueryOperations> odidDeviceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'odidDevice');
    });
  }

  QueryBuilder<IdentityEntity, List<int>?, QQueryOperations>
      privateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'privateKey');
    });
  }

  QueryBuilder<IdentityEntity, List<int>, QQueryOperations>
      publicKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publicKey');
    });
  }

  QueryBuilder<IdentityEntity, int, QQueryOperations> registrationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'registrationId');
    });
  }

  QueryBuilder<IdentityEntity, TrustLevel, QQueryOperations>
      trustLevelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trustLevel');
    });
  }

  QueryBuilder<IdentityEntity, int?, QQueryOperations> verifiedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'verifiedAt');
    });
  }
}
