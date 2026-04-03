// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CardRecordAdapter extends TypeAdapter<CardRecord> {
  @override
  final int typeId = 1;

  @override
  CardRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return CardRecord(
      id: (fields[0] as String?) ?? '',
      cardCode: (fields[1] as String?) ?? '',
      name: (fields[2] as String?) ?? '',
      imageUrl: (fields[3] as String?) ?? '',
      dateAddedUtc: (fields[4] as DateTime?) ?? DateTime.now(),
      setName: (fields[5] as String?) ?? '',
      rarity: (fields[6] as String?) ?? '',
      color: (fields[7] as String?) ?? '',
      type: (fields[8] as String?) ?? '',
      text: (fields[9] as String?) ?? '',
      attribute: (fields[10] as String?) ?? '',
      quantity: (fields[11] as int?) ?? 1,
      collectionType: (fields[12] as String?) ?? 'owned',
      deckName: fields[13] as String?,
      isFavorite: (fields[14] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, CardRecord obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.cardCode)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.dateAddedUtc)
      ..writeByte(5)
      ..write(obj.setName)
      ..writeByte(6)
      ..write(obj.rarity)
      ..writeByte(7)
      ..write(obj.color)
      ..writeByte(8)
      ..write(obj.type)
      ..writeByte(9)
      ..write(obj.text)
      ..writeByte(10)
      ..write(obj.attribute)
      ..writeByte(11)
      ..write(obj.quantity)
      ..writeByte(12)
      ..write(obj.collectionType)
      ..writeByte(13)
      ..write(obj.deckName)
      ..writeByte(14)
      ..write(obj.isFavorite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}