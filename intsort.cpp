/*
  Copyright (c) 2013, Durham University
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are
  met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

    * Neither the name of Durham University nor the names of its
      contributors may be used to endorse or promote products derived from
      this software without specific prior written permission.


   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
   IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
   TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
   PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
   OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.  
*/

/* Author: Tomasz Koziara */

#include <stdio.h>
#include <stdlib.h>
#include <algorithm>
#include <iostream>
#include <string>
#include <sstream>
#include <cassert>
#include <iomanip>
#include "timing.h"
#include "radix_sort_ispc.h"
#include "merge_sort_ispc.h"

using namespace ispc;

extern void serial_sort (int n, unsigned int code[], int order[]);

static void progressBar(const int x, const int n, const int width = 50)
{
  assert(n > 1);
  assert(x >= 0 && x < n);
  assert(width > 10);
  const float f = static_cast<float>(x)/(n-1);
  const int   w = static_cast<int>(f * width);

  // print bar
  std::string bstr("[");
  for (int i = 0; i < width; i++)
    bstr += i < w ? '=' : ' ';
  bstr += "]";

  // print percentage 
  std::stringstream pstr0;
  pstr0 << " " << static_cast<int>(f*100.0) << " % ";
  const std::string pstr(pstr0.str());
  std::copy(pstr.begin(), pstr.end(), bstr.begin() + (width/2-2));

  std::cout << bstr;
  std::cout << (x == n-1 ? "\n" : "\r") << std::flush;
}

int main (int argc, char *argv[])
{
  int i, j, n = argc == 1 ? 1000000 : atoi(argv[1]), m = n < 100 ? 1 : 50, l = n < 100 ? n : RAND_MAX;
  double tISPC1a = 0.0, tISPC1b = 0.0, tISPC2a = 0.0, tISPC2b = 0.0, tSerial = 0.0;
  unsigned int *code = new unsigned int [n];
  int *order = new int [n];

  srand (0);

  for (i = 0; i < m; i ++)
  {
    for (j = 0; j < n; j ++) code [j] = rand() % l;

    reset_and_start_timer();

    radix_sort (n, code, order, 1);

    tISPC1a += get_elapsed_mcycles();

    if (argc != 3)
        progressBar (i, m);
  }

  printf("[radix sort ispc]:\t[%.3f] million cycles\n", tISPC1a);

  srand (0);

  for (i = 0; i < m; i ++)
  {
    for (j = 0; j < n; j ++) code [j] = rand() % l;

    reset_and_start_timer();

    merge_sort (n, code, order, 1);

    tISPC1b += get_elapsed_mcycles();

    if (argc != 3)
        progressBar (i, m);
  }

  printf("[merge sort ispc]:\t[%.3f] million cycles\n", tISPC1b);

  srand (0);

  for (i = 0; i < m; i ++)
  {
    for (j = 0; j < n; j ++) code [j] = rand() % l;

    reset_and_start_timer();

    radix_sort (n, code, order, 0);

    tISPC2a += get_elapsed_mcycles();

    if (argc != 3)
        progressBar (i, m);
  }

  printf("[radix sort ispc + tasks]:\t[%.3f] million cycles\n", tISPC2a);

  srand (0);

  for (i = 0; i < m; i ++)
  {
    for (j = 0; j < n; j ++) code [j] = rand() % l;

    reset_and_start_timer();

    merge_sort (n, code, order, 0);

    tISPC2b += get_elapsed_mcycles();

    if (argc != 3)
        progressBar (i, m);
  }

  printf("[merge sort ispc + tasks]:\t[%.3f] million cycles\n", tISPC2b);

  srand (0);

  for (i = 0; i < m; i ++)
  {
    for (j = 0; j < n; j ++) code [j] = rand() % l;

    reset_and_start_timer();

    serial_sort (n, code, order);

    tSerial += get_elapsed_mcycles();

    if (argc != 3)
        progressBar (i, m);
  }

  printf("[sort serial]:\t\t[%.3f] million cycles\n", tSerial);

  printf("\t\t\t\t(%.2fx speedup from ISPC/radix, %.2fx speedup from ISPC/radix + tasks)\n", tSerial/tISPC1a, tSerial/tISPC2a);
  printf("\t\t\t\t(%.2fx speedup from ISPC/merge, %.2fx speedup from ISPC/merge + tasks)\n", tSerial/tISPC1b, tSerial/tISPC2b);

  delete code;
  delete order;
  return 0;
}