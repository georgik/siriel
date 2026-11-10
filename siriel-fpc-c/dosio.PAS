{=======================================================================}
{ dosio.pas  -  Phase-1 stub for the DOS port/interrupt I/O surface.     }
{                                                                       }
{ FPC's built-in DOS unit (used via `uses dos`) provides the memory/    }
{ environment symbols the port relies on (GetMem/FreeMem/ReallocMem,    }
{ DosError, GetEnv, MaxAvail, Seg/Ofs, ...), so we must NOT shadow it    }
{ (that would break the heap-backed XMS layer). This small unit only    }
{ supplies the x86-hardware symbols FPC does not expose on              }
{ aarch64:                                                            }
{   * Port        - x86 port I/O (VESA/blanking register access)        }
{   * GetIntVec   - read an interrupt vector                            }
{   * SetIntVec   - install an interrupt vector                         }
{                                                                       }
{ Phase 1 is compile-only; the bodies are harmless no-ops. Real         }
{ behaviour (SDL audio IRQ for SMIX, etc.) is a Phase-2 concern.        }
{=======================================================================}
{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit DOSIO;

interface

(* Port mirrors the original TP7 declaration: `Port` was literally
   array[0..65535] of Byte, so `Port[X]` reads and `Port[X] :=` writes both
   work with plain array syntax. -Mtp forbids function/procedure overloading,
   so we do NOT emulate the two-armed Port here. The real byte accesses went
   to hardware via inline asm; on aarch64 they are just a memory mirror in
   Phase 1. *)
var
  Port: array[0..65535] of Byte;

procedure GetIntVec(IntNo: Word; var Vector: Pointer);
procedure SetIntVec(IntNo: Word; Vector: Pointer);

(* MemAvail is a Turbo Pascal built-in (available conventional memory) that
   FPC does not expose. Phase-1 stub reports ample free memory so allocation
   guards (e.g. FLIK's `IF MemAvail < BufSize`) pass through. *)
function MemAvail: LongInt;

implementation

(* Phase-1 stubs: no real interrupt I/O on aarch64. *)
procedure GetIntVec(IntNo: Word; var Vector: Pointer);
begin Vector := nil; end;

procedure SetIntVec(IntNo: Word; Vector: Pointer);
begin end;

function MemAvail: LongInt;
begin MemAvail := $3FFFFFFF; end;

end.
