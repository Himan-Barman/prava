import { IsBoolean } from 'class-validator';

export class FollowStateDto {
  @IsBoolean()
  follow!: boolean;
}
