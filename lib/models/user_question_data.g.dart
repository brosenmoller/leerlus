// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_question_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserQuestionDataAdapter extends TypeAdapter<UserQuestionData> {
  @override
  final int typeId = 0;

  @override
  UserQuestionData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserQuestionData(
      questionId: fields[0] as String,
      streak: fields[1] as int,
      easeFactor: fields[2] as double,
      intervalSeconds: fields[3] as double,
      spacedRepetitionEnabled: fields[6] as bool,
      enrollmentChangedAt: fields[7] as DateTime?,
      lastReviewed: fields[4] as DateTime?,
      nextReview: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserQuestionData obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.questionId)
      ..writeByte(1)
      ..write(obj.streak)
      ..writeByte(2)
      ..write(obj.easeFactor)
      ..writeByte(3)
      ..write(obj.intervalSeconds)
      ..writeByte(4)
      ..write(obj.lastReviewed)
      ..writeByte(5)
      ..write(obj.nextReview)
      ..writeByte(6)
      ..write(obj.spacedRepetitionEnabled)
      ..writeByte(7)
      ..write(obj.enrollmentChangedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserQuestionDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
