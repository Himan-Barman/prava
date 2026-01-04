import {
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

export class UserDetailsDto {
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  @Matches(/^[A-Za-z][A-Za-z '\\-]*$/)
  firstName!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(64)
  @Matches(/^[A-Za-z][A-Za-z '\\-]*$/)
  lastName!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(8)
  @Matches(/^\+?\d{1,4}$/)
  phoneCountryCode!: string;

  @IsString()
  @MinLength(4)
  @MaxLength(20)
  @Matches(/^\d+$/)
  phoneNumber!: string;
}
