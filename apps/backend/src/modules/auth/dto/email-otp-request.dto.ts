import { IsEmail } from 'class-validator';

export class EmailOtpRequestDto {
  @IsEmail()
  email!: string;
}
