import { IsString, MaxLength, MinLength } from 'class-validator';

import { MAX_MESSAGE_BODY_LENGTH } from '@/common/constants';

export class EditMessageDto {
  @IsString()
  @MinLength(1)
  @MaxLength(MAX_MESSAGE_BODY_LENGTH)
  body!: string;
}
