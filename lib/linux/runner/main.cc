#include "EVOM_SPORlication.h"

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = EVOM_SPORlication_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
