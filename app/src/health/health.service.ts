import { Injectable } from '@nestjs/common';

@Injectable()
export class HealthService {
  checkHealth(): string {
    console.log('Chequei a saúde da aplicação! - V2');
    return 'OK - V2';
  }
  
  checkReady(): string {
    console.log('Chequei a prontidão da aplicação! - V2');
    return 'OK - V2';
  }
}
