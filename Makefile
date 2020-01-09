# Select architecture: RV32 or RV64.
ARCH ?= RV64

ifeq ($(ARCH),32)
  override ARCH := RV32
else ifeq ($(ARCH),64)
  override ARCH := RV64
endif

ifeq ($(ARCH),RV32)
  SAIL_XLEN := riscv_xlen32.sail
else ifeq ($(ARCH),RV64)
  SAIL_XLEN := riscv_xlen64.sail
else
  $(error '$(ARCH)' is not a valid architecture, must be one of: RV32, RV64)
endif


CONFIG_ISA=config/isa_$(ARCH).yaml
CONFIG_PLATFORM=config/platform.yaml
GENERATED_CONFIG_DIR=generated_definitions/config
RV_CONFIG=riscv-config
RV_CONFIG2SAIL=rv_conf2sail
RV_CONFIG_SAIL=$(GENERATED_CONFIG_DIR)/riscv_config_$(ARCH).sail
RV_CONFIG_TYPES:=$(shell opam config var riscv_config2sail:share)/riscv_config_types.sail

# Instruction sources, depending on target
SAIL_CHECK_SRCS = riscv_addr_checks_common.sail riscv_addr_checks.sail riscv_misa_ext.sail
SAIL_DEFAULT_INST = riscv_insts_base.sail riscv_insts_aext.sail riscv_insts_cext.sail riscv_insts_mext.sail riscv_insts_zicsr.sail riscv_insts_next.sail
SAIL_SEQ_INST  = $(SAIL_DEFAULT_INST) riscv_jalr_seq.sail
SAIL_RMEM_INST = $(SAIL_DEFAULT_INST) riscv_jalr_rmem.sail riscv_insts_rmem.sail

SAIL_SEQ_INST_SRCS  = riscv_insts_begin.sail $(SAIL_SEQ_INST) riscv_insts_end.sail
SAIL_RMEM_INST_SRCS = riscv_insts_begin.sail $(SAIL_RMEM_INST) riscv_insts_end.sail

# System and platform sources
SAIL_SYS_SRCS =  riscv_csr_map.sail
SAIL_SYS_SRCS += riscv_next_regs.sail
SAIL_SYS_SRCS += riscv_sys_exceptions.sail  # default basic helpers for exception handling
SAIL_SYS_SRCS += riscv_sync_exception.sail  # define the exception structure used in the model
SAIL_SYS_SRCS += riscv_next_control.sail    # helpers for the 'N' extension
SAIL_SYS_SRCS += riscv_csr_ext.sail         # access to CSR extensions
SAIL_SYS_SRCS += riscv_sys_control.sail     # general exception handling

SAIL_RV32_VM_SRCS = riscv_vmem_sv32.sail riscv_vmem_rv32.sail
SAIL_RV64_VM_SRCS = riscv_vmem_sv39.sail riscv_vmem_sv48.sail riscv_vmem_rv64.sail

SAIL_VM_SRCS = riscv_pte.sail riscv_ptw.sail riscv_vmem_common.sail riscv_vmem_tlb.sail
ifeq ($(ARCH),RV32)
SAIL_VM_SRCS += $(SAIL_RV32_VM_SRCS)
else
SAIL_VM_SRCS += $(SAIL_RV64_VM_SRCS)
endif

# Non-instruction sources
PRELUDE = prelude.sail prelude_mapping.sail $(SAIL_XLEN) prelude_mem_metadata.sail prelude_mem.sail

SAIL_REGS_SRCS = riscv_reg_type.sail riscv_regs.sail riscv_pc_access.sail riscv_sys_regs.sail
SAIL_REGS_SRCS += riscv_pmp_regs.sail riscv_pmp_control.sail
SAIL_REGS_SRCS += riscv_ext_regs.sail $(SAIL_CHECK_SRCS)

SAIL_ARCH_SRCS = $(PRELUDE)
SAIL_ARCH_SRCS += riscv_types_ext.sail riscv_types.sail
SAIL_ARCH_SRCS += riscv_vmem_types.sail $(SAIL_REGS_SRCS) $(SAIL_SYS_SRCS) riscv_platform.sail
SAIL_ARCH_SRCS += riscv_mem.sail $(SAIL_VM_SRCS)
SAIL_ARCH_RVFI_SRCS = $(PRELUDE) rvfi_dii.sail riscv_types_ext.sail riscv_types.sail riscv_vmem_types.sail $(SAIL_REGS_SRCS) $(SAIL_SYS_SRCS) riscv_platform.sail riscv_mem.sail $(SAIL_VM_SRCS)
SAIL_STEP_SRCS = riscv_step_common.sail riscv_step_ext.sail riscv_decode_ext.sail riscv_fetch.sail riscv_step.sail
RVFI_STEP_SRCS = riscv_step_common.sail riscv_step_rvfi.sail riscv_decode_ext.sail riscv_fetch_rvfi.sail riscv_step.sail

# Control inclusion of 64-bit only riscv_analysis
ifeq ($(ARCH),RV32)
SAIL_OTHER_SRCS     = $(SAIL_STEP_SRCS)
SAIL_OTHER_COQ_SRCS = riscv_termination_common.sail riscv_termination_rv32.sail
else
SAIL_OTHER_SRCS     = $(SAIL_STEP_SRCS) riscv_analysis.sail
SAIL_OTHER_COQ_SRCS = riscv_termination_common.sail riscv_termination_rv64.sail riscv_analysis.sail
endif

RV_CONFIG_SRCS =  $(RV_CONFIG_TYPES) $(RV_CONFIG_SAIL)

PRELUDE_SRCS   = $(RV_CONFIG_SRCS) $(addprefix model/,$(PRELUDE))
SAIL_SRCS      = $(RV_CONFIG_SRCS) $(addprefix model/,$(SAIL_ARCH_SRCS) $(SAIL_SEQ_INST_SRCS)  $(SAIL_OTHER_SRCS))
SAIL_RMEM_SRCS = $(RV_CONFIG_SRCS) $(addprefix model/,$(SAIL_ARCH_SRCS) $(SAIL_RMEM_INST_SRCS) $(SAIL_OTHER_SRCS))
SAIL_RVFI_SRCS = $(RV_CONFIG_SRCS) $(addprefix model/,$(SAIL_ARCH_RVFI_SRCS) $(SAIL_SEQ_INST_SRCS) $(RVFI_STEP_SRCS))
SAIL_COQ_SRCS  = $(RV_CONFIG_SRCS) $(addprefix model/,$(SAIL_ARCH_SRCS) $(SAIL_SEQ_INST_SRCS) $(SAIL_OTHER_COQ_SRCS))

PLATFORM_OCAML_SRCS = $(addprefix ocaml_emulator/,platform.ml platform_impl.ml riscv_ocaml_sim.ml)

SAIL_FLAGS += -dno_cast

# Attempt to work with either sail from opam or built from repo in SAIL_DIR
ifneq ($(SAIL_DIR),)
# Use sail repo in SAIL_DIR
SAIL:=$(SAIL_DIR)/sail
export SAIL_DIR
else
# Use sail from opam package
SAIL_DIR:=$(shell opam config var sail:share)
SAIL:=sail
endif
SAIL_LIB_DIR:=$(SAIL_DIR)/lib
export SAIL_LIB_DIR
SAIL_SRC_DIR:=$(SAIL_DIR)/src

LEM_DIR?=$(shell opam config var lem:share)
export LEM_DIR
#Coq BBV library hopefully checked out in directory above us
BBV_DIR?=../bbv

C_WARNINGS ?=
#-Wall -Wextra -Wno-unused-label -Wno-unused-parameter -Wno-unused-but-set-variable -Wno-unused-function
C_INCS = $(addprefix c_emulator/,riscv_prelude.h riscv_platform_impl.h riscv_platform.h)
C_SRCS = $(addprefix c_emulator/,riscv_prelude.c riscv_platform_impl.c riscv_platform.c riscv_sim.c)

# portability for MacPorts/MacOS
C_SYS_INCLUDES = -I /opt/local/include
C_SYS_LIBDIRS  = -L /opt/local/lib

C_FLAGS = $(C_SYS_INCLUDES) -I $(SAIL_LIB_DIR) -I c_emulator
C_LIBS  = $(C_SYS_LIBDIRS) -lgmp -lz

# The C simulator can be built to be linked against Spike for tandem-verification.
# This needs the C bindings to Spike from https://github.com/SRI-CSL/l3riscv
# TV_SPIKE_DIR in the environment should point to the top-level dir of the L3
# RISC-V, containing the built C bindings to Spike.
# RISCV should be defined if TV_SPIKE_DIR is.
ifneq (,$(TV_SPIKE_DIR))
C_FLAGS += -I $(TV_SPIKE_DIR)/src/cpp -DENABLE_SPIKE
C_LIBS  += -L $(TV_SPIKE_DIR) -ltv_spike -Wl,-rpath=$(TV_SPIKE_DIR)
C_LIBS  += -L $(RISCV)/lib -lfesvr -lriscv -Wl,-rpath=$(RISCV)/lib
endif

# SAIL_FLAGS = -dtc_verbose 4
SAIL_FLAGS += -O -Oconstant_fold

ifneq (,$(COVERAGE))
C_FLAGS += --coverage -O1
else
C_FLAGS += -O3 -flto
endif

RISCV_EXTRAS_LEM_FILES = riscv_extras.lem mem_metadata.lem
# Feature detect if we are on the latest development version of Sail
# and use an updated lem file if so. This is just until the opam
# version catches up with changes to the barrier type.
SAIL_LATEST := $(shell $(SAIL) -have_feature FEATURE_UNION_BARRIER 1>&2 2> /dev/null; echo $$?)
ifeq ($(SAIL_LATEST),0)
RISCV_EXTRAS_LEM = $(addprefix handwritten_support/0.11/,$(RISCV_EXTRAS_LEM_FILES))
else
RISCV_EXTRAS_LEM = $(addprefix handwritten_support/,$(RISCV_EXTRAS_LEM_FILES))
endif

all: ocaml_emulator/riscv_ocaml_sim_$(ARCH) c_emulator/riscv_sim_$(ARCH) riscv_isa riscv_coq riscv_hol riscv_rmem
.PHONY: all

# the following ensures empty sail-generated .c files don't hang around and
# break future builds if sail exits badly
.DELETE_ON_ERROR: generated_definitions/c/%.c

check: $(SAIL_SRCS) model/main.sail Makefile
	$(SAIL) $(SAIL_FLAGS) $(SAIL_SRCS) model/main.sail

interpret: $(SAIL_SRCS) model/main.sail
	$(SAIL) -i $(SAIL_FLAGS) $(SAIL_SRCS) model/main.sail

riscv.smt_model: $(SAIL_SRCS)
	$(SAIL) -smt_serialize $(SAIL_FLAGS) $(SAIL_SRCS) -o riscv

cgen: $(SAIL_SRCS) model/main.sail
	$(SAIL) -cgen $(SAIL_FLAGS) $(SAIL_SRCS) model/main.sail

generated_definitions/ocaml/$(ARCH)/riscv.ml: $(SAIL_SRCS) Makefile
	mkdir -p generated_definitions/ocaml/$(ARCH)
	$(SAIL) $(SAIL_FLAGS) -ocaml -ocaml-nobuild -ocaml_build_dir generated_definitions/ocaml/$(ARCH) -o riscv $(SAIL_SRCS)

ocaml_emulator/_sbuild/riscv_ocaml_sim.native: generated_definitions/ocaml/$(ARCH)/riscv.ml ocaml_emulator/_tags $(PLATFORM_OCAML_SRCS) Makefile
	mkdir -p ocaml_emulator/_sbuild
	cp ocaml_emulator/_tags $(PLATFORM_OCAML_SRCS) generated_definitions/ocaml/$(ARCH)/*.ml ocaml_emulator/_sbuild
	cd ocaml_emulator/_sbuild && ocamlbuild -use-ocamlfind riscv_ocaml_sim.native

ocaml_emulator/_sbuild/coverage.native: generated_definitions/ocaml/$(ARCH)/riscv.ml ocaml_emulator/_tags.bisect $(PLATFORM_OCAML_SRCS) Makefile
	mkdir -p ocaml_emulator/_sbuild
	cp $(PLATFORM_OCAML_SRCS) generated_definitions/ocaml/$(ARCH)/*.ml ocaml_emulator/_sbuild
	cp ocaml_emulator/_tags.bisect ocaml_emulator/_sbuild/_tags
	cd ocaml_emulator/_sbuild && ocamlbuild -use-ocamlfind riscv_ocaml_sim.native && cp -L riscv_ocaml_sim.native coverage.native

ocaml_emulator/riscv_ocaml_sim_$(ARCH): ocaml_emulator/_sbuild/riscv_ocaml_sim.native
	rm -f $@ && cp -L $^ $@ && rm -f $^

ocaml_emulator/coverage_$(ARCH): ocaml_emulator/_sbuild/coverage.native
	rm -f ocaml_emulator/riscv_ocaml_sim_$(ARCH) && cp -L $^ ocaml_emulator/riscv_ocaml_sim_$(ARCH) # since the test scripts runs this file
	rm -rf bisect*.out bisect ocaml_emulator/coverage_$(ARCH) $^
	./test/run_tests.sh # this will generate bisect*.out files in this directory
	mkdir ocaml_emulator/bisect && mv bisect*.out bisect/
	mkdir ocaml_emulator/coverage_$(ARCH) && bisect-ppx-report -html ocaml_emulator/coverage_$(ARCH)/ -I ocaml_emulator/_sbuild/ bisect/bisect*.out

cloc:
	cloc --by-file --force-lang C,sail $(SAIL_SRCS)

gcovr:
	gcovr -r . --html --html-detail -o index.html

generated_definitions/ocaml/riscv_duopod_ocaml: $(PRELUDE_SRCS) model/riscv_duopod.sail
	mkdir -p generated_definitions/ocaml
	$(SAIL) $(SAIL_FLAGS) -ocaml -ocaml_build_dir generated_definitions/ocaml -o riscv_duopod_ocaml model/riscv_duopod.sail

ocaml_emulator/tracecmp: ocaml_emulator/tracecmp.ml
	ocamlfind ocamlopt -annot -linkpkg -package unix $^ -o $@

generated_definitions/c/riscv_model_$(ARCH).c: $(SAIL_SRCS) model/main.sail Makefile
	mkdir -p generated_definitions/c
	$(SAIL) $(SAIL_FLAGS) -memo_z3 -c -c_include riscv_prelude.h -c_include riscv_platform.h -c_no_main $(SAIL_SRCS) model/main.sail -o $(basename $@)

# convenience target
.PHONY: csim
csim: c_emulator/riscv_sim_$(ARCH)
.PHONY: rvfi
rvfi: c_emulator/riscv_rvfi_$(ARCH)

c_emulator/riscv_sim_$(ARCH): generated_definitions/c/riscv_model_$(ARCH).c $(C_INCS) $(C_SRCS) Makefile
	gcc -g $(C_WARNINGS) $(C_FLAGS) $< $(C_SRCS) $(SAIL_LIB_DIR)/*.c $(C_LIBS) -o $@

$(RV_CONFIG_SAIL): $(CONFIG_ISA) $(CONFIG_PLATFORM)
	mkdir -p $(GENERATED_CONFIG_DIR)
	$(RV_CONFIG) --isa_spec $(CONFIG_ISA) --platform_spec $(CONFIG_PLATFORM) --work_dir $(GENERATED_CONFIG_DIR)
	$(RV_CONFIG2SAIL) -i $(GENERATED_CONFIG_DIR)/isa_$(ARCH)_checked.yaml -p $(GENERATED_CONFIG_DIR)/platform_checked.yaml -o $@

generated_definitions/c/riscv_rvfi_model_$(ARCH).c: $(SAIL_RVFI_SRCS) model/main.sail Makefile
	mkdir -p generated_definitions/c
	$(SAIL) $(SAIL_FLAGS) -memo_z3 -c -c_include riscv_prelude.h -c_include riscv_platform.h -c_no_main $(SAIL_RVFI_SRCS) model/main.sail -o $(basename $@)
	sed -i -e '/^[[:space:]]*$$/d' $@

c_emulator/riscv_rvfi_$(ARCH): generated_definitions/c/riscv_rvfi_model_$(ARCH).c $(C_INCS) $(C_SRCS) Makefile
	gcc -g $(C_WARNINGS) $(C_FLAGS) $< -DRVFI_DII $(C_SRCS) $(SAIL_LIB_DIR)/*.c $(C_LIBS) -o $@

latex: $(SAIL_SRCS) Makefile
	mkdir -p generated_definitions/latex
	$(SAIL) -latex -latex_prefix sail -o generated_definitions/latex $(SAIL_SRCS)

generated_definitions/isabelle/$(ARCH)/ROOT: handwritten_support/ROOT
	mkdir -p generated_definitions/isabelle/$(ARCH)
	cp handwritten_support/ROOT generated_definitions/isabelle/$(ARCH)/

generated_definitions/lem/riscv_duopod.lem: $(PRELUDE_SRCS) model/riscv_duopod.sail
	mkdir -p generated_definitions/lem
	$(SAIL) $(SAIL_FLAGS) -lem -lem_output_dir generated_definitions/lem -isa_output_dir generated_definitions/isabelle -lem_mwords -lem_lib Riscv_extras -lem_lib Mem_metadata -o riscv_duopod model/riscv_duopod.sail

generated_definitions/isabelle/Riscv_duopod.thy: generated_definitions/isabelle/RV64/ROOT generated_definitions/lem/riscv_duopod.lem $(RISCV_EXTRAS_LEM)
	lem -isa -outdir generated_definitions/isabelle -lib Sail=$(SAIL_SRC_DIR)/lem_interp -lib Sail=$(SAIL_SRC_DIR)/gen_lib \
		$(RISCV_EXTRAS_LEM) \
		generated_definitions/lem/riscv_duopod_types.lem \
		generated_definitions/lem/riscv_duopod.lem

riscv_duopod: generated_definitions/ocaml/riscv_duopod_ocaml generated_definitions/isabelle/Riscv_duopod.thy

riscv_isa: generated_definitions/isabelle/$(ARCH)/Riscv.thy
riscv_isa_build: riscv_isa
ifeq ($(wildcard $(LEM_DIR)/isabelle-lib),)
	$(error Lem directory not found. Please set the LEM_DIR environment variable)
endif
ifeq ($(wildcard $(SAIL_LIB_DIR)/isabelle),)
	$(error lib directory of Sail not found. Please set the SAIL_LIB_DIR environment variable)
endif
	isabelle build -b -d $(LEM_DIR)/isabelle-lib -d $(SAIL_LIB_DIR)/isabelle -d generated_definitions/isabelle/$(ARCH) Sail-RISC-V

.PHONY: riscv_isa riscv_isa_build

generated_definitions/lem/$(ARCH)/riscv.lem: $(SAIL_SRCS) Makefile
	mkdir -p generated_definitions/lem/$(ARCH) generated_definitions/isabelle/$(ARCH)
	$(SAIL) $(SAIL_FLAGS) -lem -lem_output_dir generated_definitions/lem/$(ARCH) -isa_output_dir generated_definitions/isabelle/$(ARCH) -o riscv -lem_mwords -lem_lib Riscv_extras -lem_lib Mem_metadata $(SAIL_SRCS)
	echo "declare {isabelle} rename field sync_exception_ext = sync_exception_ext_exception" >> generated_definitions/lem/$(ARCH)/riscv_types.lem

generated_definitions/isabelle/$(ARCH)/Riscv.thy: generated_definitions/isabelle/$(ARCH)/ROOT generated_definitions/lem/$(ARCH)/riscv.lem $(RISCV_EXTRAS_LEM) Makefile
	lem -isa -outdir generated_definitions/isabelle/$(ARCH) -lib Sail=$(SAIL_SRC_DIR)/lem_interp -lib Sail=$(SAIL_SRC_DIR)/gen_lib \
		$(RISCV_EXTRAS_LEM) \
		generated_definitions/lem/$(ARCH)/riscv_types.lem \
		generated_definitions/lem/$(ARCH)/riscv.lem
	sed -i 's/datatype ast/datatype (plugins only: size) ast/' generated_definitions/isabelle/$(ARCH)/Riscv_types.thy
	sed -i "s/record( 'asidlen, 'valen, 'palen, 'ptelen) TLB_Entry/record (overloaded) ( 'asidlen, 'valen, 'palen, 'ptelen) TLB_Entry/" generated_definitions/isabelle/$(ARCH)/Riscv_types.thy
	sed -i "s/by pat_completeness auto/by pat_completeness (auto intro!: let_cong bind_cong MemoryOpResult.case_cong)/" generated_definitions/isabelle/$(ARCH)/Riscv.thy

generated_definitions/hol4/$(ARCH)/Holmakefile: handwritten_support/Holmakefile
	mkdir -p generated_definitions/hol4/$(ARCH)
	cp handwritten_support/Holmakefile generated_definitions/hol4/$(ARCH)

generated_definitions/hol4/$(ARCH)/riscvScript.sml: generated_definitions/hol4/$(ARCH)/Holmakefile generated_definitions/lem/$(ARCH)/riscv.lem $(RISCV_EXTRAS_LEM)
	lem -hol -outdir generated_definitions/hol4/$(ARCH) -lib $(SAIL_LIB_DIR)/hol -i $(SAIL_LIB_DIR)/hol/sail2_prompt_monad.lem -i $(SAIL_LIB_DIR)/hol/sail2_prompt.lem \
	    -lib $(SAIL_DIR)/src/lem_interp -lib $(SAIL_DIR)/src/gen_lib \
		$(RISCV_EXTRAS_LEM) \
		generated_definitions/lem/$(ARCH)/riscv_types.lem \
		generated_definitions/lem/$(ARCH)/riscv.lem

$(addprefix generated_definitions/hol4/$(ARCH)/,riscvTheory.uo riscvTheory.ui): generated_definitions/hol4/$(ARCH)/Holmakefile generated_definitions/hol4/$(ARCH)/riscvScript.sml
ifeq ($(wildcard $(LEM_DIR)/hol-lib),)
	$(error Lem directory not found. Please set the LEM_DIR environment variable)
endif
ifeq ($(wildcard $(SAIL_LIB_DIR)/hol),)
	$(error lib directory of Sail not found. Please set the SAIL_LIB_DIR environment variable)
endif
	(cd generated_definitions/hol4/$(ARCH) && Holmake riscvTheory.uo)

riscv_hol: generated_definitions/hol4/$(ARCH)/riscvScript.sml
riscv_hol_build: generated_definitions/hol4/$(ARCH)/riscvTheory.uo
.PHONY: riscv_hol riscv_hol_build

COQ_LIBS = -R $(BBV_DIR)/theories bbv -R $(SAIL_LIB_DIR)/coq Sail -R generated_definitions/coq/$(ARCH) '' -R handwritten_support ''

riscv_coq: $(addprefix generated_definitions/coq/$(ARCH)/,riscv.v riscv_types.v)
riscv_coq_build: generated_definitions/coq/$(ARCH)/riscv.vo
.PHONY: riscv_coq riscv_coq_build

$(addprefix generated_definitions/coq/$(ARCH)/,riscv.v riscv_types.v): $(SAIL_COQ_SRCS) Makefile
	mkdir -p generated_definitions/coq/$(ARCH)
	$(SAIL) $(SAIL_FLAGS) -dcoq_undef_axioms -coq -coq_output_dir generated_definitions/coq/$(ARCH) -o riscv -coq_lib riscv_extras -coq_lib mem_metadata $(SAIL_COQ_SRCS)
$(addprefix generated_definitions/coq/$(ARCH)/,riscv_duopod.v riscv_duopod_types.v): $(PRELUDE_SRCS) model/riscv_duopod.sail model/riscv_termination_duo.sail
	mkdir -p generated_definitions/coq/$(ARCH)
	$(SAIL) $(SAIL_FLAGS) -dcoq_undef_axioms -coq -coq_output_dir generated_definitions/coq/$(ARCH) -o riscv_duopod -coq_lib riscv_extras -coq_lib mem_metadata $^

%.vo: %.v
ifeq ($(wildcard $(BBV_DIR)/theories),)
	$(error BBV directory not found. Please set the BBV_DIR environment variable)
endif
ifeq ($(wildcard $(SAIL_LIB_DIR)/coq),)
	$(error lib directory of Sail not found. Please set the SAIL_LIB_DIR environment variable)
endif
	coqc $(COQ_LIBS) $<

generated_definitions/coq/$(ARCH)/riscv.vo: generated_definitions/coq/$(ARCH)/riscv_types.vo handwritten_support/riscv_extras.vo handwritten_support/mem_metadata.vo
generated_definitions/coq/$(ARCH)/riscv_duopod.vo: generated_definitions/coq/$(ARCH)/riscv_duopod_types.vo handwritten_support/riscv_extras.vo handwritten_support/mem_metadata.vo

echo_rmem_srcs:
	echo $(SAIL_RMEM_SRCS)

riscv_rmem: generated_definitions/for-rmem/riscv.lem
riscv_rmem: generated_definitions/for-rmem/riscv_toFromInterp2.ml
riscv_rmem: generated_definitions/for-rmem/riscv.defs
.PHONY: riscv_rmem

generated_definitions/for-rmem/riscv.lem: SAIL_FLAGS += -lem_lib Riscv_extras -lem_lib Mem_metadata
generated_definitions/for-rmem/riscv.lem: $(SAIL_RMEM_SRCS)
	mkdir -p $(dir $@)
#	We do not need the isabelle .thy files, but sail always generates them
	$(SAIL) $(SAIL_FLAGS) -lem -lem_mwords -lem_output_dir $(dir $@) -isa_output_dir $(dir $@) -o $(notdir $(basename $@)) $^

generated_definitions/for-rmem/riscv_toFromInterp2.ml: $(SAIL_RMEM_SRCS)
	mkdir -p $(dir $@)
	$(SAIL) $(SAIL_FLAGS) -tofrominterp -tofrominterp_lem -tofrominterp_mwords -tofrominterp_output_dir $(dir $@) -o riscv $^

generated_definitions/for-rmem/riscv.defs: $(SAIL_RMEM_SRCS)
	mkdir -p $(dir $@)
	$(SAIL) $(SAIL_FLAGS) -marshal -o $(basename $@) $^

# we exclude prelude.sail here, most code there should move to sail lib
#LOC_FILES:=$(SAIL_SRCS) main.sail
#include $(SAIL_DIR)/etc/loc.mk

FORCE:

SHARE_FILES:=$(wildcard model/*.sail) $(wildcard c_emulator/*.c) $(wildcard c_emulator/*.h)
sail-riscv.install: FORCE
	echo 'bin: ["c_emulator/riscv_sim_RV64" "c_emulator/riscv_sim_RV32"]' > sail-riscv.install
	echo 'share: [ $(foreach f,$(SHARE_FILES),"$f" {"$f"}) ]' >> sail-riscv.install

opam-build:
	$(MAKE) ARCH=64 c_emulator/riscv_sim_RV64
	$(MAKE) ARCH=32 c_emulator/riscv_sim_RV32

opam-install:
	if [ -z "$(INSTALL_DIR)" ]; then echo INSTALL_DIR is unset; false; fi
	mkdir -p $(INSTALL_DIR)/bin
	cp c_emulator/riscv_sim_RV64 $(INSTALL_DIR)/bin
	cp c_emulator/riscv_sim_RV32 $(INSTALL_DIR)/bin

opam-uninstall:
	if [ -z "$(INSTALL_DIR)" ]; then echo INSTALL_DIR is unset; false; fi
	rm $(INSTALL_DIR)/bin/riscv_sim_RV64
	rm $(INSTALL_DIR)/bin/riscv_sim_RV32

clean:
	-rm -rf generated_definitions/ocaml/* generated_definitions/c/* generated_definitions/latex/*
	-rm -rf generated_definitions/lem/* generated_definitions/isabelle/* generated_definitions/hol4/* generated_definitions/coq/*
	-rm -rf generated_definitions/for-rmem/*
	-rm -f c_emulator/riscv_sim_RV32 c_emulator/riscv_sim_RV64  c_emulator/riscv_rvfi_RV32 c_emulator/riscv_rvfi_RV64
	-rm -rf ocaml_emulator/_sbuild ocaml_emulator/_build ocaml_emulator/riscv_ocaml_sim_RV32 ocaml_emulator/riscv_ocaml_sim_RV64 ocaml_emulator/tracecmp
	-rm -f *.gcno *.gcda
	-rm -f z3_problems
	-Holmake cleanAll
	-rm -f handwritten_support/riscv_extras.vo handwritten_support/riscv_extras.glob handwritten_support/.riscv_extras.aux
	-rm -f handwritten_support/mem_metadata.vo handwritten_support/mem_metadata.glob handwritten_support/.mem_metadata.aux
	ocamlbuild -clean
