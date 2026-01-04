import { IsUUID } from 'class-validator';

export class CreateDmDto {
  @IsUUID()
  otherUserId!: string;
}
