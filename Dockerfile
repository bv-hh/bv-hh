FROM ruby:3.2.3-alpine3.18

RUN apk add --update build-base bash bash-completion libffi-dev tzdata postgresql-client postgresql-dev nodejs npm yarn cargo

WORKDIR /bv-hh

COPY Gemfile* /bv-hh/

RUN gem install bundler

RUN bundle install
RUN rails assets:precompile

CMD [ "/bin/bash" ]