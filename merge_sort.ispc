/*
  Copyright (c) 2015, Tomasz Koziara
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are
  met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

    * Neither the name of Tomasz Koziara nor the names of its
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

typedef unsigned int uint;

/* quick sort on unsigned integers */
static void quick_sort (uniform uint a[], uniform int n, uniform int order[])
{
  uniform uint p, t;
  uniform int i, j;

  if (n < 2) return;

  p = a[n/2];

  for (i = 0, j = n - 1;; i++, j--)
  {
    while (a[i] < p) i++;
    while (p < a[j]) j--;
    if (i >= j) break;

    t = a[i];
    a[i] = a[j];
    a[j] = t;

    t = order[i];
    order[i] = order[j];
    order[j] = t;
  }

  quick_sort (a, i, order);
  quick_sort (a+i, n-i, order+i);
}

/* parallel quick sort task */
task void quick_task (uniform int span, uniform int n, uniform uint a[], uniform int order[])
{
  uniform int start = taskIndex*span;
  uniform int end = taskIndex == taskCount-1 ? n : start+span;

  quick_sort (a+start, end-start, order+start);
}

/* merge tree for parallel quick sort */
struct merge_tree
{
  uniform int leaf;
  uniform int parent;
  uniform int left;
  uniform int right;

  uniform uint * uniform b;
  uniform int * uniform p;
};

/* create in place merge tree and store b[] and p[] at leaves */
static void build_tree (uniform int parent, uniform int node, uniform merge_tree tree[],
 uniform int * uniform i, uniform int span, uniform uint b[], uniform int p[], uniform int n)
{
  if (n == 1)
  {
    tree[node].parent = parent;
    tree[node].leaf =
    tree[node].left =
    tree[node].right = node;

    tree[node].b = b;
    tree[node].p = p;
  }
  else
  {
    tree[node].parent = parent;
    tree[node].leaf = -1;
    tree[node].left = ++(*i);
    tree[node].right = ++(*i);

    tree[node].b = NULL;
    tree[node].p = NULL;

    build_tree (node, tree[node].left, tree, i, span, b, p, n/2);
    build_tree (node, tree[node].right, tree, i, span, b+span*(n/2), p+span*(n/2), n-n/2);
  }
}

/* initialise merge tree leaf pointers */
static uniform int init_leaf (uniform int left, uniform int right, uniform merge_tree tree[])
{
  if (tree[left].leaf < 0) tree[left].leaf = init_leaf (tree[left].left, tree[left].right, tree);
  if (tree[right].leaf < 0) tree[right].leaf = init_leaf (tree[right].left, tree[right].right, tree);

  if (tree[tree[left].leaf].b[0] < tree[tree[right].leaf].b[0]) return tree[left].leaf;
  else return tree[right].leaf;
}

/* sort n unsigned integers and return their ordering */
export void merge_sort (uniform int n, uniform uint a[], uniform int order[], uniform int threads)
{
  uniform int num = threads < 1 ? num_cores () : threads;
  uniform int span = n/num + 1; /* one extre stopgap item per range */
  uniform int i, j, start, end;

  uniform uint * uniform b = uniform new uniform uint[n+num]; /* initial size plus stopgaps */
  uniform int * uniform p = uniform new uniform int[n+num];

  for (j = 0; j < num; j ++) /* initialise buffers */
  {
    start = j*span;
    end = j == num-1 ? n+num : start+span;

    foreach (k = start ... end-1) b[k] = a[k-j];

    b[end-1] = 0xFFFFFFFFu; /* stopgap prevents going beyond range when merging */

    foreach (k = start ... end-1) p[k] = k-j; /* mind the back shift, k-j, here and above */

    p[end-1] = -1;
  }

  launch[num] quick_task (span, n+num, b, p); /* parallel fragmented quick sort */
  sync;

  uniform merge_tree * uniform tree = uniform new uniform merge_tree [2*num]; /* tree and leaves size */

  i = 0;
  build_tree (-1, 0, tree, &i, span, b, p, num); /* build in place tree */
  tree->leaf = init_leaf (tree->left, tree->right, tree); /* initialise leaf pointers */

  for (i = 0; i < n; i ++) /* merge loop */
  {
    uniform int leaf = tree->leaf; /* root leaf pointer is the smallest element */

    a[i] = *(tree[leaf].b++); /* get and iterate array */
    order[i] = *(tree[leaf].p++); /* get and iterate order */

    uniform int node = tree[leaf].parent; /* leaf's parent starts tree update */

    while (node >= 0) /* climb the tree and update leaf pointers */
    {
      if (tree[tree[tree[node].left].leaf].b[0] < /* select smaller leaf of the two siblings */
	  tree[tree[tree[node].right].leaf].b[0]) tree[node].leaf = tree[tree[node].left].leaf;
      else tree[node].leaf = tree[tree[node].right].leaf;

      node = tree[node].parent; /* climb up */
    }
  }

  /* O((n/m)log(n/m)) + O(n*log(m)), where n - input size, m - number of tasks */

  delete b;
  delete p;
  delete tree;
}
