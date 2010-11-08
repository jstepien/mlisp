#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdarg.h>
#include <string.h>
#include "constants.h"

/* Types' values are defined in constants.rb. */
#define obj_type(x) ((((struct meta*)(x))->flags >> TYPE_OFFSET) & TYPE_BITS)
#define is_int(x) ((x) && obj_type(x) == TYPE_INT)
#define is_node(x) ((x) && obj_type(x) == TYPE_NODE)
#define is_symbol(x) ((x) && obj_type(x) == TYPE_SYMBOL)
#define is_string(x) ((x) && obj_type(x) == TYPE_STRING)
/* An empty list is represented as a NULL. */
#define empty_list (NULL)
#define is_empty_list(x) (!(x))

/* Contains some metadata about an object. Currently it's just a 32 bit long
 * flags field in which information about the object's type is stored. */
struct meta {
	int32_t flags;
};

/* Represents an integer. */
struct num {
	struct meta meta;
	int32_t value;
};

/* Represents a node of a list. */
struct node {
	struct meta meta;
	void *data;
	struct node *next;
};

/* Represents a symbol. The 'name' field points to a char array with an
 * appropriate lexeme. */
struct symbol {
	struct meta meta;
	char *name;
};

/* Represents a string. The 'value' field points to a char array with an
 * appropriate lexeme. */
struct string {
	struct meta meta;
	char *value;
};

/* A 't symbol. */
struct symbol true = { { TYPE_SYMBOL << TYPE_OFFSET }, "t" };

static void print_list(struct node *node);

/* Prints arguments to stderr and exits with an error status. */
static void die(const char *format, ...) {
	va_list ap;
	va_start(ap, format);
	vfprintf(stderr, format, ap);
	exit(1);
}

/* Prints a given object to stdout. If the object contains children (i.e. is a
 * list) they are printed recursively. If add_space is non-zero a space
 * character is printed at the end of the output. */
static void print_recur(void *object, int add_space) {
	if (is_empty_list(object))
		printf("()");
	else if (is_int(object))
		printf("%i", ((struct num*) object)->value);
	else if (is_node(object)) {
		print_list((struct node*) object);
	} else if (is_symbol(object))
		printf("%s", ((struct symbol*) object)->name);
	else if (is_string(object))
		printf("\"%s\"", ((struct string*) object)->value);
	else
		die("Unknown type: %i\n", obj_type(object));
	if (add_space)
		printf(" ");
}

/* Prints all elements of a list surrounded with parentheses. */
static void print_list(struct node *node) {
	printf("(");
	while (node) {
		print_recur(node->data, (int) node->next);
		node = node->next;
	}
	printf(")");
}

/* Prints a given object to stdout. */
void print(void *object) {
	print_recur(object, 0);
	printf("\n");
}

/* Returns a new list node. */
static struct node * new_node() {
	struct node *node = calloc(1, sizeof(struct node));
	node->meta.flags |= TYPE_NODE;
	return node;
}

/* Returns a new num struct. */
static struct num * new_num(int value) {
	struct num *num = calloc(1, sizeof(struct num));
	num->meta.flags |= TYPE_INT;
	num->value = value;
	return num;
}

/* Returns a new list with head being car and tail being cdr. */
struct node * cons(void *head, void *tail) {
	struct node *node = new_node();
	if (is_empty_list(tail))
		node->next = empty_list;
	else if (is_int(tail)) {
		node->next = new_node();
		node->next->data = tail;
	} else if (is_node(tail)) {
		node->next = tail;
	} else
		die("Unknown type: %i\n", obj_type(tail));
	node->data = head;
	return node;
}

struct node * cdr(void *head) {
	if (is_node(head))
		return ((struct node *) head)->next;
	die("Wrong type for cdr: %i\n", obj_type(head));
	return 0; /* Won't be reached anyway. */
}

void * car(void *head) {
	if (is_node(head))
		return ((struct node *) head)->data;
	die("Wrong type for car: %i\n", obj_type(head));
	return 0; /* Won't be reached anyway. */
}

#define DEFINE_CXXR(i,j) \
	void * c##i##j##r(void *head) { return c##i##r(c##j##r(head)); }
DEFINE_CXXR(a,a)
DEFINE_CXXR(a,d)
DEFINE_CXXR(d,d)
DEFINE_CXXR(d,a)
#undef DEFINE_CXXR

#define DEFINE_CXXXR(i,j,k) \
	void * c##i##j##k##r(void *head) { return c##i##r(c##j##r(c##k##r(head))); }
DEFINE_CXXXR(a,a,a)
DEFINE_CXXXR(a,a,d)
DEFINE_CXXXR(a,d,d)
DEFINE_CXXXR(d,d,d)
DEFINE_CXXXR(d,d,a)
DEFINE_CXXXR(d,a,d)
DEFINE_CXXXR(a,d,a)
#undef DEFINE_CXXXR

/* True if the object isn't a list. */
void * atom(void *object) {
	if (object && is_node(object))
		return empty_list;
	else
		return &true;
}

/* True if both objects are identical symbols or numbers. */
void * eq(void *a, void *b) {
	int type_a;
	if (is_empty_list(a) && is_empty_list(b))
		return &true;
	if (is_empty_list(a) || is_empty_list(b))
		return empty_list;
	type_a = obj_type(a);
	if (type_a == obj_type(b)) {
		if (type_a == TYPE_INT &&
				((struct num*) a)->value == ((struct num*) b)->value)
			return &true;
		if (type_a == TYPE_SYMBOL &&
				!strcmp(((struct symbol*) a)->name, ((struct symbol*) b)->name))
			return &true;
	}
	return empty_list;
}

/* Returns a new list having arguments as elements. */
void * list(void * arg, ...) {
	struct node *node = empty_list, *prev = empty_list, *first;
	va_list ap;
	va_start(ap, arg);
	while ((unsigned int) arg != VAR_ARG_DELIM) {
		node = new_node();
		node->data = arg;
		if (prev)
			prev->next = node;
		else
			first = node;
		arg = va_arg(ap, void *);;
		prev = node;
	}
	va_end(ap);
	return first;
}

/* Returns true if the object is a number. */
void * numberp(void *object) {
	if (is_empty_list(object))
		return empty_list;
	else if (is_int(object))
		return &true;
	else
		return empty_list;
}

/* Raises an error if the object is an empty list. */
void * assert(void *object) {
	if (is_empty_list(object))
		die("Assertion failed\n");
	return empty_list;
}

void * GT(void *a, void *b) {
	if (numberp(a) && numberp(b))
		if (((struct num*) a)->value > ((struct num*) b)->value)
			return &true;
		else
			return empty_list;
	else
		die("GT: Unexpected types\n");
	return empty_list;
}

void * MUL(void *a, void *b) {
	if (is_int(a) && is_int(b))
		return new_num(((struct num*) a)->value * ((struct num*) b)->value);
	else
		die("MUL: Unexpected types\n");
	return empty_list;
}

void * SUB(void *a, void *b) {
	if (is_int(a) && is_int(b))
		return new_num(((struct num*) a)->value - ((struct num*) b)->value);
	else
		die("SUB: Unexpected types\n");
	return empty_list;
}
