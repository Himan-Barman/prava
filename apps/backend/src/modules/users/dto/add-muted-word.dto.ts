import { IsString, MaxLength, MinLength } from 'class-validator';

export class AddMutedWordDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  phrase!: string;
}
