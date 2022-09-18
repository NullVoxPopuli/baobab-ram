import { getOwner } from '@ember/application';
import Helper from '@ember/component/helper';
import { type Registry } from '@ember/service';

export class Service<Key extends keyof Registry> extends Helper<{
  Args: {
    Positional: [serviceName: Key];
  };
  Return: Registry[Key];
}> {
  compute([name]: [Key]) {
    return getOwner(this).lookup(`service:${name}`) as Registry[Key];
  }
}

export const service = Service;
export default Service;
