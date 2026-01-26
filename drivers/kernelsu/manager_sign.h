#ifndef __KSU_H_MANAGER_SIGN
#define __KSU_H_MANAGER_SIGN

#include <linux/types.h>

// rsuntk/KernelSU
#define EXPECTED_SIZE_RSUNTK 0x396
#define EXPECTED_HASH_RSUNTK                                                   \
	"f415f4ed9435427e1fdf7f1fccd4dbc07b3d6b8751e4dbcec6f19671f427870b"

// 5ec1cff/KernelSU
#define EXPECTED_SIZE_5EC1CFF 0x3e6
#define EXPECTED_HASH_5EC1CFF                                                  \
	"79e590113c4c4c0c222978e413a5faa801666957b1212a328e46c00c69821bf7"

// tiann/KernelSU
#define EXPECTED_SIZE_OFFICIAL 0x033b
#define EXPECTED_HASH_OFFICIAL                                                 \
	"c371061b19d8c7d7d6133c6a9bafe198fa944e50c1b31c9d8daa8d7f1fc2d2d6"

// KOWX712/KernelSU
#define EXPECTED_SIZE_KOWX712 0x35c
#define EXPECTED_HASH_KOWX712                                                  \
	"947ae944f3de4ed4c21a7e4f7953ecf351bfa2b36239da37a34111ad29993eef"

typedef struct {
	u32 size;
	const char *sha256;
} apk_sign_key_t;

#endif /* MANAGER_SIGN_H */
