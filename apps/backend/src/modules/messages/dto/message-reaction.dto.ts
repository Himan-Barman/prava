import { IsString, MaxLength, MinLength } from 'class-validator';

export class MessageReactionDto {
  @IsString()
  @MinLength(1)
  @MaxLength(16)
  emoji!: string;
}
