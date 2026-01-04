// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prekey_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPreKeyEntityCollection on Isar {
  IsarCollection<PreKeyEntity> get preKeyEntitys => this.collection();
}

const PreKeyEntitySchema = CollectionSchema(
  name: r'PreKeyEntity',
  id: -1589910534322156642,
  properties: {
    r'consumed': PropertySchema(
      id: 0,
      name: r'consumed',
      type: IsarType.bool,
    ),
    r'consumedAt': PropertySchema(
      id: 1,
      name: r'consumedAt',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.long,
    ),
    r'keyId': PropertySchema(
      id: 3,
      name: r'keyId',
      type: IsarType.long,
    ),
    r'privateKey': PropertySchema(
      id: 4,
      name: r'privateKey',
      type: IsarType.longList,
    ),
    r'publicKey': PropertySchema(
      id: 5,
      name: r'publicKey',
      type: IsarType.longList,
    ),
    r'uploaded': PropertySchema(
      id: 6,
      name: r'uploaded',
      type: IsarType.bool,
    )
  },
  estimateSize: _preKeyEntityEstimateSize,
  serialize: _preKeyEntitySerialize,
  deserialize: _preKeyEntityDeserialize,
  deserializeProp: _preKeyEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'keyId': IndexSchema(
      id: 2852921932302977192,
      name: r'keyId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'keyId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'uploaded': IndexSchema(
      id: 4523767140989849088,
      name: r'uploaded',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'uploaded',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'consumed': IndexSchema(
      id: 1196921977313145160,
      name: r'consumed',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'consumed',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _preKeyEntityGetId,
  getLinks: _preKeyEntityGetLinks,
  attach: _preKeyEntityAttach,
  version: '3.1.0+1',
);

int _preKeyEntityEstimateSize(
  PreKeyEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.privateKey.length * 8;
  bytesCount += 3 + object.publicKey.length * 8;
  return bytesCount;
}

void _preKeyEntitySerialize(
  PreKeyEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.consumed);
  writer.writeLong(offsets[1], object.consumedAt);
  writer.writeLong(offsets[2], object.createdAt);
  writer.writeLong(offsets[3], object.keyId);
  writer.writeLongList(offsets[4], object.privateKey);
  writer.writeLongList(offsets[5], object.publicKey);
  writer.writeBool(offsets[6], object.uploaded);
}

PreKeyEntity _preKeyEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PreKeyEntity();
  object.consumed = reader.readBool(offsets[0]);
  object.consumedAt = reader.readLongOrNull(offsets[1]);
  object.createdAt = reader.readLong(offsets[2]);
  object.id = id;
  object.keyId = reader.readLong(offsets[3]);
  object.privateKey = reader.readLongList(offsets[4]) ?? [];
  object.publicKey = reader.readLongList(offsets[5]) ?? [];
  object.uploaded = reader.readBool(offsets[6]);
  return object;
}

P _preKeyEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLongList(offset) ?? []) as P;
    case 5:
      return (reader.readLongList(offset) ?? []) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _preKeyEntityGetId(PreKeyEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _preKeyEntityGetLinks(PreKeyEntity object) {
  return [];
}

void _preKeyEntityAttach(
    IsarCollection<dynamic> col, Id id, PreKeyEntity object) {
  object.id = id;
}

extension PreKeyEntityByIndex on IsarCollection<PreKeyEntity> {
  Future<PreKeyEntity?> getByKeyId(int keyId) {
    return getByIndex(r'keyId', [keyId]);
  }

  PreKeyEntity? getByKeyIdSync(int keyId) {
    return getByIndexSync(r'keyId', [keyId]);
  }

  Future<bool> deleteByKeyId(int keyId) {
    return deleteByIndex(r'keyId', [keyId]);
  }

  bool deleteByKeyIdSync(int keyId) {
    return deleteByIndexSync(r'keyId', [keyId]);
  }

  Future<List<PreKeyEntity?>> getAllByKeyId(List<int> keyIdValues) {
    final values = keyIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'keyId', values);
  }

  List<PreKeyEntity?> getAllByKeyIdSync(List<int> keyIdValues) {
    final values = keyIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'keyId', values);
  }

  Future<int> deleteAllByKeyId(List<int> keyIdValues) {
    final values = keyIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'keyId', values);
  }

  int deleteAllByKeyIdSync(List<int> keyIdValues) {
    final values = keyIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'keyId', values);
  }

  Future<Id> putByKeyId(PreKeyEntity object) {
    return putByIndex(r'keyId', object);
  }

  Id putByKeyIdSync(PreKeyEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'keyId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByKeyId(List<PreKeyEntity> objects) {
    return putAllByIndex(r'keyId', objects);
  }

  List<Id> putAllByKeyIdSync(List<PreKeyEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'keyId', objects, saveLinks: saveLinks);
  }
}

extension PreKeyEntityQueryWhereSort
    on QueryBuilder<PreKeyEntity, PreKeyEntity, QWhere> {
  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhere> anyKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'keyId'),
      );
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhere> anyUploaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'uploaded'),
      );
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhere> anyConsumed() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'consumed'),
      );
    });
  }
}

extension PreKeyEntityQueryWhere
    on QueryBuilder<PreKeyEntity, PreKeyEntity, QWhereClause> {
  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> idBetween(
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> keyIdEqualTo(
      int keyId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'keyId',
        value: [keyId],
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> keyIdNotEqualTo(
      int keyId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'keyId',
              lower: [],
              upper: [keyId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'keyId',
              lower: [keyId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'keyId',
              lower: [keyId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'keyId',
              lower: [],
              upper: [keyId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> keyIdGreaterThan(
    int keyId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'keyId',
        lower: [keyId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> keyIdLessThan(
    int keyId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'keyId',
        lower: [],
        upper: [keyId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> keyIdBetween(
    int lowerKeyId,
    int upperKeyId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'keyId',
        lower: [lowerKeyId],
        includeLower: includeLower,
        upper: [upperKeyId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> uploadedEqualTo(
      bool uploaded) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'uploaded',
        value: [uploaded],
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause>
      uploadedNotEqualTo(bool uploaded) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uploaded',
              lower: [],
              upper: [uploaded],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uploaded',
              lower: [uploaded],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uploaded',
              lower: [uploaded],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uploaded',
              lower: [],
              upper: [uploaded],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause> consumedEqualTo(
      bool consumed) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'consumed',
        value: [consumed],
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterWhereClause>
      consumedNotEqualTo(bool consumed) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'consumed',
              lower: [],
              upper: [consumed],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'consumed',
              lower: [consumed],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'consumed',
              lower: [consumed],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'consumed',
              lower: [],
              upper: [consumed],
              includeUpper: false,
            ));
      }
    });
  }
}

extension PreKeyEntityQueryFilter
    on QueryBuilder<PreKeyEntity, PreKeyEntity, QFilterCondition> {
  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
      consumedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'consumed',
        value: value,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
      consumedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'consumedAt',
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
      consumedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'consumedAt',
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
      consumedAtEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'consumedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
      consumedAtGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'consumedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
      consumedAtLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'consumedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
      consumedAtBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'consumedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
      createdAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition> idBetween(
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition> keyIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'keyId',
        value: value,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition> keyIdLessThan(
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition> keyIdBetween(
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
      privateKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'privateKey',
        value: value,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
      publicKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterFilterCondition>
      uploadedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uploaded',
        value: value,
      ));
    });
  }
}

extension PreKeyEntityQueryObject
    on QueryBuilder<PreKeyEntity, PreKeyEntity, QFilterCondition> {}

extension PreKeyEntityQueryLinks
    on QueryBuilder<PreKeyEntity, PreKeyEntity, QFilterCondition> {}

extension PreKeyEntityQuerySortBy
    on QueryBuilder<PreKeyEntity, PreKeyEntity, QSortBy> {
  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> sortByConsumed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumed', Sort.asc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> sortByConsumedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumed', Sort.desc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> sortByConsumedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.asc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy>
      sortByConsumedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.desc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> sortByKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.asc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> sortByKeyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.desc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> sortByUploaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploaded', Sort.asc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> sortByUploadedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploaded', Sort.desc);
    });
  }
}

extension PreKeyEntityQuerySortThenBy
    on QueryBuilder<PreKeyEntity, PreKeyEntity, QSortThenBy> {
  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> thenByConsumed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumed', Sort.asc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> thenByConsumedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumed', Sort.desc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> thenByConsumedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.asc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy>
      thenByConsumedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.desc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> thenByKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.asc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> thenByKeyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.desc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> thenByUploaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploaded', Sort.asc);
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QAfterSortBy> thenByUploadedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploaded', Sort.desc);
    });
  }
}

extension PreKeyEntityQueryWhereDistinct
    on QueryBuilder<PreKeyEntity, PreKeyEntity, QDistinct> {
  QueryBuilder<PreKeyEntity, PreKeyEntity, QDistinct> distinctByConsumed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'consumed');
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QDistinct> distinctByConsumedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'consumedAt');
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QDistinct> distinctByKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'keyId');
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QDistinct> distinctByPrivateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'privateKey');
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QDistinct> distinctByPublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publicKey');
    });
  }

  QueryBuilder<PreKeyEntity, PreKeyEntity, QDistinct> distinctByUploaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uploaded');
    });
  }
}

extension PreKeyEntityQueryProperty
    on QueryBuilder<PreKeyEntity, PreKeyEntity, QQueryProperty> {
  QueryBuilder<PreKeyEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PreKeyEntity, bool, QQueryOperations> consumedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'consumed');
    });
  }

  QueryBuilder<PreKeyEntity, int?, QQueryOperations> consumedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'consumedAt');
    });
  }

  QueryBuilder<PreKeyEntity, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<PreKeyEntity, int, QQueryOperations> keyIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'keyId');
    });
  }

  QueryBuilder<PreKeyEntity, List<int>, QQueryOperations> privateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'privateKey');
    });
  }

  QueryBuilder<PreKeyEntity, List<int>, QQueryOperations> publicKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publicKey');
    });
  }

  QueryBuilder<PreKeyEntity, bool, QQueryOperations> uploadedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uploaded');
    });
  }
}
