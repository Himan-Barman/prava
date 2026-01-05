import {
  IsBoolean,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class SupportTicketDto {
  @IsIn(['help', 'report', 'feedback'])
  type!: 'help' | 'report' | 'feedback';

  @IsOptional()
  @IsString()
  @MaxLength(32)
  category?: string;

  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  message!: string;

  @IsOptional()
  @IsBoolean()
  includeLogs?: boolean;

  @IsOptional()
  @IsBoolean()
  allowContact?: boolean;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(5)
  score?: number;
}
