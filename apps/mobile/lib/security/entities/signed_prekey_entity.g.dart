// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signed_prekey_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSignedPreKeyEntityCollection on Isar {
  IsarCollection<SignedPreKeyEntity> get signedPreKeyEntitys =>
      this.collection();
}

const SignedPreKeyEntitySchema = CollectionSchema(
  name: r'SignedPreKeyEntity',
  id: -4749318747359311314,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.long,
    ),
    r'isActive': PropertySchema(
      id: 1,
      name: r'isActive',
      type: IsarType.bool,
    ),
    r'keyId': PropertySchema(
      id: 2,
      name: r'keyId',
      type: IsarType.long,
    ),
    r'privateKey': PropertySchema(
      id: 3,
      name: r'privateKey',
      type: IsarType.longList,
    ),
    r'publicKey': PropertySchema(
      id: 4,
      name: r'publicKey',
      type: IsarType.longList,
    ),
    r'signature': PropertySchema(
      id: 5,
      name: r'signature',
      type: IsarType.longList,
    )
  },
  estimateSize: _signedPreKeyEntityEstimateSize,
  serialize: _signedPreKeyEntitySerialize,
  deserialize: _signedPreKeyEntityDeserialize,
  deserializeProp: _signedPreKeyEntityDeserializeProp,
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
    r'isActive': IndexSchema(
      id: 8092228061260947457,
      name: r'isActive',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isActive',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _signedPreKeyEntityGetId,
  getLinks: _signedPreKeyEntityGetLinks,
  attach: _signedPreKeyEntityAttach,
  version: '3.1.0+1',
);

int _signedPreKeyEntityEstimateSize(
  SignedPreKeyEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.privateKey.length * 8;
  bytesCount += 3 + object.publicKey.length * 8;
  bytesCount += 3 + object.signature.length * 8;
  return bytesCount;
}

void _signedPreKeyEntitySerialize(
  SignedPreKeyEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.createdAt);
  writer.writeBool(offsets[1], object.isActive);
  writer.writeLong(offsets[2], object.keyId);
  writer.writeLongList(offsets[3], object.privateKey);
  writer.writeLongList(offsets[4], object.publicKey);
  writer.writeLongList(offsets[5], object.signature);
}

SignedPreKeyEntity _signedPreKeyEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SignedPreKeyEntity();
  object.createdAt = reader.readLong(offsets[0]);
  object.id = id;
  object.isActive = reader.readBool(offsets[1]);
  object.keyId = reader.readLong(offsets[2]);
  object.privateKey = reader.readLongList(offsets[3]) ?? [];
  object.publicKey = reader.readLongList(offsets[4]) ?? [];
  object.signature = reader.readLongList(offsets[5]) ?? [];
  return object;
}

P _signedPreKeyEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLongList(offset) ?? []) as P;
    case 4:
      return (reader.readLongList(offset) ?? []) as P;
    case 5:
      return (reader.readLongList(offset) ?? []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _signedPreKeyEntityGetId(SignedPreKeyEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _signedPreKeyEntityGetLinks(
    SignedPreKeyEntity object) {
  return [];
}

void _signedPreKeyEntityAttach(
    IsarCollection<dynamic> col, Id id, SignedPreKeyEntity object) {
  object.id = id;
}

extension SignedPreKeyEntityByIndex on IsarCollection<SignedPreKeyEntity> {
  Future<SignedPreKeyEntity?> getByKeyId(int keyId) {
    return getByIndex(r'keyId', [keyId]);
  }

  SignedPreKeyEntity? getByKeyIdSync(int keyId) {
    return getByIndexSync(r'keyId', [keyId]);
  }

  Future<bool> deleteByKeyId(int keyId) {
    return deleteByIndex(r'keyId', [keyId]);
  }

  bool deleteByKeyIdSync(int keyId) {
    return deleteByIndexSync(r'keyId', [keyId]);
  }

  Future<List<SignedPreKeyEntity?>> getAllByKeyId(List<int> keyIdValues) {
    final values = keyIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'keyId', values);
  }

  List<SignedPreKeyEntity?> getAllByKeyIdSync(List<int> keyIdValues) {
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

  Future<Id> putByKeyId(SignedPreKeyEntity object) {
    return putByIndex(r'keyId', object);
  }

  Id putByKeyIdSync(SignedPreKeyEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'keyId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByKeyId(List<SignedPreKeyEntity> objects) {
    return putAllByIndex(r'keyId', objects);
  }

  List<Id> putAllByKeyIdSync(List<SignedPreKeyEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'keyId', objects, saveLinks: saveLinks);
  }
}

extension SignedPreKeyEntityQueryWhereSort
    on QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QWhere> {
  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhere> anyKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'keyId'),
      );
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhere>
      anyIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isActive'),
      );
    });
  }
}

extension SignedPreKeyEntityQueryWhere
    on QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QWhereClause> {
  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
      idBetween(
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
      keyIdEqualTo(int keyId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'keyId',
        value: [keyId],
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
      keyIdNotEqualTo(int keyId) {
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
      keyIdGreaterThan(
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
      keyIdLessThan(
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
      keyIdBetween(
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
      isActiveEqualTo(bool isActive) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isActive',
        value: [isActive],
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterWhereClause>
      isActiveNotEqualTo(bool isActive) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isActive',
              lower: [],
              upper: [isActive],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isActive',
              lower: [isActive],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isActive',
              lower: [isActive],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isActive',
              lower: [],
              upper: [isActive],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SignedPreKeyEntityQueryFilter
    on QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QFilterCondition> {
  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      createdAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      isActiveEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isActive',
        value: value,
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      keyIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'keyId',
        value: value,
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      privateKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'privateKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      publicKeyElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publicKey',
        value: value,
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
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

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      signatureElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'signature',
        value: value,
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      signatureElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'signature',
        value: value,
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      signatureElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'signature',
        value: value,
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      signatureElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'signature',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      signatureLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signature',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      signatureIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signature',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      signatureIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signature',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      signatureLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signature',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      signatureLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signature',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterFilterCondition>
      signatureLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'signature',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension SignedPreKeyEntityQueryObject
    on QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QFilterCondition> {}

extension SignedPreKeyEntityQueryLinks
    on QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QFilterCondition> {}

extension SignedPreKeyEntityQuerySortBy
    on QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QSortBy> {
  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      sortByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      sortByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      sortByKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.asc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      sortByKeyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.desc);
    });
  }
}

extension SignedPreKeyEntityQuerySortThenBy
    on QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QSortThenBy> {
  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      thenByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      thenByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      thenByKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.asc);
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QAfterSortBy>
      thenByKeyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keyId', Sort.desc);
    });
  }
}

extension SignedPreKeyEntityQueryWhereDistinct
    on QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QDistinct> {
  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QDistinct>
      distinctByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isActive');
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QDistinct>
      distinctByKeyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'keyId');
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QDistinct>
      distinctByPrivateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'privateKey');
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QDistinct>
      distinctByPublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publicKey');
    });
  }

  QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QDistinct>
      distinctBySignature() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'signature');
    });
  }
}

extension SignedPreKeyEntityQueryProperty
    on QueryBuilder<SignedPreKeyEntity, SignedPreKeyEntity, QQueryProperty> {
  QueryBuilder<SignedPreKeyEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SignedPreKeyEntity, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SignedPreKeyEntity, bool, QQueryOperations> isActiveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isActive');
    });
  }

  QueryBuilder<SignedPreKeyEntity, int, QQueryOperations> keyIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'keyId');
    });
  }

  QueryBuilder<SignedPreKeyEntity, List<int>, QQueryOperations>
      privateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'privateKey');
    });
  }

  QueryBuilder<SignedPreKeyEntity, List<int>, QQueryOperations>
      publicKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publicKey');
    });
  }

  QueryBuilder<SignedPreKeyEntity, List<int>, QQueryOperations>
      signatureProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'signature');
    });
  }
}
