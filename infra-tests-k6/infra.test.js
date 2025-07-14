import http from 'k6/http';
import { check } from 'k6';

export let options = {
  vus: 1, 
  duration: '10s',
};

const BASE_URL = 'http://localhost:8443/api';

export default function () {
  let healthRes = http.get(`${BASE_URL}/health`);
  check(healthRes, {
    'health status is 200': (res) => res.status === 200,
    'health body contains status': (res) => res.json().status === 'ok',
  });

  let usersRes = http.get(`${BASE_URL}/users`);
  check(usersRes, {
    'users status is 200': (res) => res.status === 200,
    'users is array': (res) => Array.isArray(res.json()),
  });
}
