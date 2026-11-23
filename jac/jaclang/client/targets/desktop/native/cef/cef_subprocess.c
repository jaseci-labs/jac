// Helper binary CEF launches for its renderer, GPU and utility processes.
int cef_dispatch_execute_process(void);

int main(void) {
  int code = cef_dispatch_execute_process();
  return code >= 0 ? code : 1;
}
