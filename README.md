# nginx-timings
nginx request execution time monitoring

# HowTo

1. Set Nginx shared dictionary (http section) and path to search lib + init
```

lua_shared_dict log_dict 5M;
lua_package_path "/etc/nginx/sites-available/?.lua;;";
init_by_lua 'require("logger")';

```

2. Add log_by_lua block in location
<key> used to differentiate logical part pf monitoring
<float> used to set precision of time (numbers after point)

```
...

log_by_lua '
    log(ngx.shared.log_dict, "<key>", <float>)
';

...

```
