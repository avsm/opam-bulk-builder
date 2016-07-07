FROM ocaml/opam:alpine
RUN ssh-keyscan -H github.com > /home/opam/.ssh/known_hosts
RUN git clone -b master git://github.com/avsm/mirage-bulk-logs /home/opam/data
WORKDIR /home/opam/data
RUN git remote add worigin git@github.com:avsm/mirage-bulk-logs
COPY command.sh /home/opam/command.sh
