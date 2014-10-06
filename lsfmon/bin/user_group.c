#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lsf/lsbatch.h>

int main(int argc, char* argv[]) {
  char* filename = "group_info.txt";
  if (argc > 1) filename = argv[1];

  if (lsb_init(argv[0]) < 0) {
    lsb_perror("lsb_init");
    exit(-1);
  }

  char *user = ALL_USERS;             /* match jobs for all users */
  int options = PEND_JOB | RUN_JOB;
  if (lsb_openjobinfo(0, NULL, user, NULL, NULL, options) < 0) {
    lsb_perror("lsb_openjobinfo");
    exit(-1);
  }

  FILE* fp = fopen(filename, "w");
  if (fp == NULL) {
    perror("Error while opening the file.\n");
    exit(EXIT_FAILURE);
  }
  int more;
  for (;;) {
    struct jobInfoEnt *job = lsb_readjobinfo(&more);
    if (job == NULL) {
      lsb_perror("lsb_readjobinfo");
      exit(-1);
    }
    if ((job->submit.options & SUB_USER_GROUP)) {
      /* display job information */
      char host[32];
      char jidstr[32];
      strcpy(host, "");
      if (job->status == 4) strcpy(host, job->exHosts[0]);

      int jobid = job->jobId;
      sprintf(jidstr, "%d", jobid);
      if (LSB_ARRAY_IDX(jobid) != 0) 
        sprintf(jidstr, "%d[%d]", LSB_ARRAY_JOBID(jobid), LSB_ARRAY_IDX(jobid)); 
      fprintf(fp, "%s %s %d %s\n",
	 jidstr, 
         job->user, 
         job->status, 
         job->submit.userGroup);
    }
    if (!more) 
      break;
  }
  fclose(fp);

  lsb_closejobinfo();
  exit(0);
}
