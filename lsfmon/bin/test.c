#include <stdio.h>
#include <stdlib.h>
#include <lsf/lsbatch.h>

int main(int argc, char* argv[]) {
  int  options = PEND_JOB | RUN_JOB | UGRP_INFO;
  char *user = ALL_USERS;             /* match jobs for all users */
  struct jobInfoEnt *job;
  FILE* fp;
  int more;

  if (lsb_init(argv[0]) < 0) {
    lsb_perror("lsb_init");
    exit(-1);
  }

  if (lsb_openjobinfo(0, NULL, user, NULL, NULL, options) < 0) {
    lsb_perror("lsb_openjobinfo");
    exit(-1);
  }

#if 0
  printf("All pending/running jobs submitted by all users:\n");
  printf("    JOBID      USER    STAT  QUEUE      FROM_HOST   EXEC_HOST   USER_GROUP JOB_NAME   SUBMIT_TIME\n");
#endif
  fp = fopen("/tmp/group_info.txt", "w");
  if (fp == NULL) {
     perror("Error while opening the file.\n");
     exit(EXIT_FAILURE);
  }
  for (;;) {
    job = lsb_readjobinfo(&more);
    if (job == NULL) {
      lsb_perror("lsb_readjobinfo");
      exit(-1);
    }
    if ((job->submit.options & SUB_USER_GROUP)) {
      /* display job information */
      char *host = "";
      if (job->status == 4) host = job->exHosts[0];
      fprintf(fp, "%ld %s %d %s\n",
         job->jobId, 
              job->user, 
              job->status, 
              job->submit.userGroup);
    }
    if (! more) 
      break;
  }
  fclose(fp);

  lsb_closejobinfo();
  exit(0);
}
