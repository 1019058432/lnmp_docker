FROM php:7.0-fpm-alpine
ENV TZ "Asia/Shanghai"
ENV TERM xterm
# 默认关闭opcode
ENV OPCODE 0

COPY ./php/conf.d/ $PHP_INI_DIR/conf.d/
COPY ./php/composer.phar /usr/local/bin/composer
COPY ./php/www.conf /usr/local/etc/php-fpm.d/www.conf
# 创建www用户
RUN addgroup -g 1000 -S www && adduser -s /sbin/nologin -S -D -u 1000 -G www www
# 配置阿里云镜像源，加快构建速度
RUN sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories

# PHPIZE_DEPS 包含 gcc g++ 等编译辅助类库，完成编译后删除
RUN apk add --no-cache $PHPIZE_DEPS \
    && apk add --no-cache libstdc++ libzip-dev vim \
    && apk update \
    && pecl install redis-5.3.4 \
    && pecl install zip \
    # && pecl install swoole \
    && docker-php-ext-enable redis zip \ 
    #swoole\
    && apk del $PHPIZE_DEPS \
    && apk add nginx    \
    && mkdir -p /run/nginx/
COPY ./conf.d /etc/nginx/conf.d
COPY ./php-slim /www/php-slim
COPY ./50x.html /usr/share/nginx/html
# docker-php-ext-install 指令已经包含编译辅助类库的删除逻辑
RUN apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev \
    && apk update \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install -j$(nproc) pdo_mysql \
    && docker-php-ext-install -j$(nproc) opcache \
    && docker-php-ext-install -j$(nproc) bcmath \
    && docker-php-ext-install -j$(nproc) mysqli \
    && chmod +x /usr/local/bin/composer \
    #加载nginx的自定义conf
    && nginx -c /etc/nginx/nginx.conf 

#Install language pack
#配置字符编码
RUN apk --no-cache add ca-certificates wget && \
    wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-2.25-r0.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-bin-2.25-r0.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-i18n-2.25-r0.apk && \
    apk add glibc-bin-2.25-r0.apk glibc-i18n-2.25-r0.apk glibc-2.25-r0.apk
#Iterate through all locale and install it
#Note that locale -a is not available in alpine linux, use `/usr/glibc-compat/bin/locale -a` instead
COPY ./locale.md /locale.md
RUN cat locale.md | xargs -i /usr/glibc-compat/bin/localedef -i {} -f UTF-8 {}.UTF-8
#Set the lang, you can also specify it as as environment variable through docker-compose.yml
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

# COPY ./logs /www/logs
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
WORKDIR /www/php-slim/
# RUN composer install #如果携带vendor即不需要install,启动容器及容器内的nginx( nginx -c /etc/nginx/nginx.conf && nginx)后直接composer dump-autoload -o即可
# RUN composer install --ignore-platform-reqs #or composer update --ignore-platform-reqs #忽略版本匹配安装
EXPOSE 80
# 启动nginx，关闭守护式运行，否则容器启动后会立刻关闭
# CMD ["nginx", "-g", "daemon off;"]
ENTRYPOINT ["php-fpm"]
