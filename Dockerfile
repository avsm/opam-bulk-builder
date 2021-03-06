FROM ocaml/opam:alpine
MAINTAINER Anil Madhavapeddy <anil@recoil.org>
RUN sudo apk add --update jq
RUN sudo curl -fL "https://raw.githubusercontent.com/buildkite/docker-ssh-env-config/master/ssh-env-config.sh" -o /usr/bin/ssh-env-config.sh \
    && sudo chmod +x /usr/bin/ssh-env-config.sh
RUN ssh-keyscan -H github.com > /home/opam/.ssh/known_hosts
RUN git clone git://github.com/avsm/jsontee && cd jsontee && make jsontee && sudo cp jsontee /usr/bin/jsontee
RUN git clone -b master git://github.com/avsm/mirage-bulk-logs /home/opam/data
WORKDIR /home/opam/data
RUN git remote add worigin git@github.com:avsm/mirage-bulk-logs
COPY command.sh /home/opam/command.sh
COPY build-package.sh /home/opam/build-package.sh
ENTRYPOINT ["/usr/bin/ssh-env-config.sh","/home/opam/command.sh"]
