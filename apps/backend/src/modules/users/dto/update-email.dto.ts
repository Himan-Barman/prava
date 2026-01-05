import { IsEmail, MaxLength } from 'class-validator';

export class UpdateEmailDto {
  @IsEmail()
  @MaxLength(255)
  email!: string;
}
