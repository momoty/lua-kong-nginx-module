# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(1);

plan tests => repeat_each() * (blocks() * 5);

my $pwd = cwd();

$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: not calling request_client_certificate, not requesting client to present cert
--- http_config
    lua_package_path "../lua-resty-core/lib/?.lua;lualib/?.lua;;";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   example.com;
        ssl_certificate_by_lua_block { print("ssl cert by lua is running!") }
        ssl_certificate ../../cert/example.com.crt;
        ssl_certificate_key ../../cert/example.com.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {
                ngx.say("DN: ", ngx.var.ssl_client_s_dn)
                ngx.say("Verify: ", ngx.var.ssl_client_verify)
                ngx.say("Chain: ", require("resty.kong.tls").get_full_client_certificate_chain())
            }
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;

    location /t {
        proxy_ssl_certificate ../../cert/client_example.com.crt;
        proxy_ssl_certificate_key ../../cert/client_example.com.key;
        proxy_ssl_trusted_certificate ../../cert/ca.crt;
        proxy_ssl_verify on;
        proxy_ssl_name example.com;
        proxy_pass https://unix:$TEST_NGINX_HTML_DIR/nginx.sock:/foo;
    }

--- request
GET /t
--- response_body
DN: nil
Verify: NONE
Chain: nil

--- error_log
[lua] ssl_certificate_by_lua:1: ssl cert by lua is running!

--- no_error_log
[error]
[alert]



=== TEST 2: calling request_client_certificate, client is requested
to present cert but not presenting, request still goes through
--- http_config
    lua_package_path "../lua-resty-core/lib/?.lua;lualib/?.lua;;";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   example.com;
        ssl_certificate_by_lua_block {
            print("ssl cert by lua is running!")

            print("request_client_certificate: ",
                  require("resty.kong.tls").request_client_certificate())
        }
        ssl_certificate ../../cert/example.com.crt;
        ssl_certificate_key ../../cert/example.com.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {
                ngx.say("DN: ", ngx.var.ssl_client_s_dn)
                ngx.say("Verify: ", ngx.var.ssl_client_verify)
                ngx.say("Chain: ", require("resty.kong.tls").get_full_client_certificate_chain())
            }
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;

    location /t {
        # proxy_ssl_certificate ../../cert/client_example.com.crt;
        # proxy_ssl_certificate_key ../../cert/client_example.com.key;
        proxy_ssl_trusted_certificate ../../cert/ca.crt;
        proxy_ssl_verify on;
        proxy_ssl_name example.com;
        proxy_pass https://unix:$TEST_NGINX_HTML_DIR/nginx.sock:/foo;
    }

--- request
GET /t
--- response_body
DN: nil
Verify: NONE
Chain: nil

--- error_log
[lua] ssl_certificate_by_lua:2: ssl cert by lua is running!

--- no_error_log
[error]
[alert]



=== TEST 3: calling request_client_certificate, client is requested
to present cert and is presenting, cert can be retrieved using API
--- http_config
    lua_package_path "../lua-resty-core/lib/?.lua;lualib/?.lua;;";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   example.com;
        ssl_certificate_by_lua_block {
            print("ssl cert by lua is running!")

            print("request_client_certificate: ",
                  require("resty.kong.tls").request_client_certificate())
        }
        ssl_certificate ../../cert/example.com.crt;
        ssl_certificate_key ../../cert/example.com.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {
                ngx.say("DN: ", ngx.var.ssl_client_s_dn)
                ngx.say("Verify: ", ngx.var.ssl_client_verify)
                local chain = require("resty.kong.tls").get_full_client_certificate_chain()
                if chain then
                chain = chain:sub(0, -2)
                end
                ngx.say("Chain: ", chain)
            }
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;

    location /t {
        proxy_ssl_certificate ../../cert/client_example.com.crt;
        proxy_ssl_certificate_key ../../cert/client_example.com.key;
        proxy_ssl_trusted_certificate ../../cert/ca.crt;
        proxy_ssl_verify on;
        proxy_ssl_name example.com;
        proxy_pass https://unix:$TEST_NGINX_HTML_DIR/nginx.sock:/foo;
    }

--- request
GET /t
--- response_body
DN: CN=foo@example.com,O=Kong Testing,ST=California,C=US
Verify: FAILED:unable to get local issuer certificate
Chain: -----BEGIN CERTIFICATE-----
MIIFIjCCAwqgAwIBAgICIAEwDQYJKoZIhvcNAQELBQAwYDELMAkGA1UEBhMCVVMx
EzARBgNVBAgMCkNhbGlmb3JuaWExFTATBgNVBAoMDEtvbmcgVGVzdGluZzElMCMG
A1UEAwwcS29uZyBUZXN0aW5nIEludGVybWlkaWF0ZSBDQTAeFw0xOTA1MDIyMDAz
MTFaFw0yOTA0MjgyMDAzMTFaMFMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxp
Zm9ybmlhMRUwEwYDVQQKDAxLb25nIFRlc3RpbmcxGDAWBgNVBAMMD2Zvb0BleGFt
cGxlLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJldMxsZHDxA
RpbSXdIFZiTf8D0dYgsPnsmx5tVjA/zrVBSVBPO9KunaXNm4Z6JWmUwenzFGbzWP
NLfbLn4khuoczzqSru5XfbyH1HrD0cd5lkf44Dw1/otfIFDBleiR/OWEiAxwS4zi
xIajNyvLr3gC5dv+F+JuWpW1yVQxybIDQWoI25xpd3+ZkXO+OLkToo+YpuwIDlUj
6Rkm5kbqoxDpaDihA2bsAqjNG7G+SHthaNyACsQsU/t6BHSWzHumScN0CxJ+TeVH
fTZklelItZ6YP0B0RQjzvSGA423UgALzqJglGPe8UDjm3BMlg2xhTfnfy1J6Vmbt
5jx6FOXUARsCAwEAAaOB8jCB7zAJBgNVHRMEAjAAMBEGCWCGSAGG+EIBAQQEAwIF
oDAzBglghkgBhvhCAQ0EJhYkT3BlblNTTCBHZW5lcmF0ZWQgQ2xpZW50IENlcnRp
ZmljYXRlMB0GA1UdDgQWBBRTzNOmhGRXaZamxVfnlKXarIOEmDAfBgNVHSMEGDAW
gBQLDgQOl/htYk8k8DvGb9IKO40RETAOBgNVHQ8BAf8EBAMCBeAwHQYDVR0lBBYw
FAYIKwYBBQUHAwIGCCsGAQUFBwMEMCsGA1UdEQQkMCKBD2Zvb0BleGFtcGxlLmNv
bYEPYmFyQGV4YW1wbGUuY29tMA0GCSqGSIb3DQEBCwUAA4ICAQBziDuVjU0I1CwO
b1Cx2TJpzi3l5FD/ozrMZT6F3EpkJFGZWgXrsXHz/0qKTrsbB2m3/fcyd0lwQ5Lh
fz8X1HPrwXa3BqZskNu1vOUNiqAYWvQ5gtbpweJ96LzMSYVGLK78NigYTtK+Rgq3
As5CVfLXDBburrQNGyRTsilCQDNBvIpib0eqg/HJCNDFMPrBzTMPpUutyatfpFH2
UwTiVBfA14YYDxZaetYWeksy28XH6Uj0ylyz67VHND+gBMmQNLXQHJTIDh8JuIf2
ec6o4HrtyyuRE3urNQmcPMAokacm4NKw2+og6Rg1VS/pckaSPOlSEmNnKFiXStv+
AVd77NGriUWDFCmnrFNOPOIS019W0oOk6YMwTUDSa86Ii6skCtBLHmp/cingkTWg
7KEbdT1uVVPgseC2AFpQ1BWJOjjtyW3GWuxERIhuab9/ckTz6BuIiuK7mfsvPBrn
BqjZyt9WAx8uaWMS/ZrmIj3fUXefaPtl27jMSsiU5oi2vzFu0xiXJb6Jr7RQxD3O
XRnycL/chWnp7eVV1TQS+XzZ3ZZQIjckDWX4E+zGo4o9pD1YC0eytbIlSuqYVr/t
dZmD2gqju3Io9EXPDlRDP2VIX9q1euF9caz1vpLCfV+F8wVPtZe5p6JbNugdgjix
nDZ2sD2xGXy6/fNG75oHveYo6MREFw==
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIFmjCCA4KgAwIBAgICEAAwDQYJKoZIhvcNAQELBQAwWDELMAkGA1UEBhMCVVMx
EzARBgNVBAgMCkNhbGlmb3JuaWExFTATBgNVBAoMDEtvbmcgVGVzdGluZzEdMBsG
A1UEAwwUS29uZyBUZXN0aW5nIFJvb3QgQ0EwHhcNMTkwNTAyMTk0MDQ4WhcNMjkw
NDI5MTk0MDQ4WjBgMQswCQYDVQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEV
MBMGA1UECgwMS29uZyBUZXN0aW5nMSUwIwYDVQQDDBxLb25nIFRlc3RpbmcgSW50
ZXJtaWRpYXRlIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA0dnj
oHlJmNM94vQnK2FIIQJm9OAVvyMtAAkBKL7Cxt8G062GHDhq6gjQ9enuNQE0l3Vv
mSAh7N9gNlma6YbRB9VeG54BCuRQwCxveOBiwQvC2qrTzYI34kF/AeflrDOdzuLb
zj5cLADKXGCbGDtrSPKUwdlkuLs3pRr/YAyIQr7zJtlLz+E0GBYp0GWnLs0FiLSP
qSBWllC9u8gt2MiKyNlXw+kZ8lofOehCJzfFr6qagVklPw+8IpU6OGmRLFQVwVhp
zdAJmAGmSo/AGNKGqDdjzC4N2l4uYGH6n2KmY2yxsLBGZgwtLDst3fK4a3Wa5Tj7
cUwCcGLGtfVTaIXZYbqQ0nGsaYUd/mhx3B3Jk1p3ILZ72nVYowhpj22ipPGal5hp
ABh1MX3s/B+2ybWyDTtSaspcyhsRQsS6axB3DwLOLRy5Xp/kqEdConCtGCsjgm+U
FzdupubXK+KIAmTKXDx8OM7Af/K7kLDfFTre40sEB6fwrWwH8yFojeqkA/Uqhn5S
CzB0o4F3ON0xajsw2dRCziiq7pSe6ALLXetKpBr+xnVbUswH6BANUoDvh9thVPPx
1trkv+OuoJalkruZaT+38+iV9xwdqxnR7PUawqSyvrEAxjqUo7dDPsEuOpx1DJjO
XwRJCUjd7Ux913Iks24BqpPhEQz/rZzJLBApRVsCAwEAAaNmMGQwHQYDVR0OBBYE
FAsOBA6X+G1iTyTwO8Zv0go7jRERMB8GA1UdIwQYMBaAFAdP8giF4QLaR0HEj9N8
apTFYnD3MBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMA0GCSqG
SIb3DQEBCwUAA4ICAQAWzIvIVM32iurqM451Amz0HNDG9j84cORnnaRR5opFTr3P
EqI3QkgCyP6YOs9t0QSbA4ur9WUzd3c9Ktj3qRRgTE+98JBOPO0rv+Kjj48aANDV
5tcbI9TZ9ap6g0jYr4XNT+KOO7E8QYlpY/wtokudCUDJE9vrsp1on4Bal2gjvCdh
SU0C1lnj6q6kBdQSYHrcjiEIGJH21ayVoNaBVP/fxyCHz472w1xN220dxUI/GqB6
pjcuy9cHjJHJKJbrkdt2eDRAFP5cILXc3mzUoGUDHY2JA1gtOHV0p4ix9R9AfI9x
snBEFiD8oIpcQay8MJH/z3NLEPLoBW+JaAAs89P+jcppea5N9vbiAkrPi687BFTP
PWPdstyttw6KrvtPQR1+FsVFcGeTjo32/UrckJixdiOEZgHk+deXpp7JoRdcsgzD
+okrsG79/LgS4icLmzNEp0IV36QckEq0+ALKDu6BXvWTkb5DB/FUrovZKJgkYeWj
GKogyrPIXrYi725Ff306124kLbxiA+6iBbKUtCutQnvut78puC6iP+a2SrfsbUJ4
qpvBFOY29Mlww88oWNGTA8QeW84Y1EJbRkHavzSsMFB73sxidQW0cHNC5t9RCKAQ
uibeZgK1Yk7YQKXdvbZvXwrgTcAjCdbppw2L6e0Uy+OGgNjnIps8K460SdaIiA==
-----END CERTIFICATE-----

--- error_log
[lua] ssl_certificate_by_lua:2: ssl cert by lua is running!

--- no_error_log
[error]
[alert]