unit emit_alloc;

{$mode objfpc}{$H+}

interface

uses
  sysutils,
  spirv,
  srNode,
  srType,
  srTypes,
  srConst,
  srRefId,
  srReg,
  srLayout,
  srVariable,
  srInput,
  srOutput,
  srVertLayout,
  srFragLayout,
  srUniform,
  srBuffer,
  srDecorate,
  srOp,
  srOpUtils,
  emit_fetch;

type
 TSprvEmit_alloc=class(TEmitFetch)
  procedure AllocStage;
  procedure AllocSpirvID(P:PsrRefId);
  procedure AllocBinding;
  procedure AllocTypeBinding;
  procedure AllocEntryPoint;
  procedure AllocHeader;
  procedure AllocOpListId(node:PspirvOp);
  procedure AllocListId(node:PsrNode);
  procedure AllocFuncId;
  procedure AllocOpId(node:PSpirvOp);
  procedure AllocOpBlock(pBlock:PsrOpBlock);
 end;

implementation

procedure TSprvEmit_alloc.AllocStage;
begin
 AllocBinding;

 BufferList.AllocTypeBinding;
 AllocTypeBinding;

 AllocHeader;

 //Source Extension
 DataLayoutList.AllocSourceExtension;
 DataLayoutList.AllocFuncExt;
 VertLayoutList.AllocSourceExtension;
 UniformList   .AllocSourceExtension;
 BufferList    .AllocSourceExtension;

 //Decorate Name
 BufferList  .AllocName;
 VariableList.AllocName;

 //header id
 AllocOpListId(HeaderList.First);
 AllocOpListId(DebugInfoList.First);
 AllocOpListId(DecorateList.First);

 //element id
 AllocListId(TypeList.First);
 AllocListId(ConstList.First);
 AllocListId(VariableList.First);

 AllocFuncId;
end;

procedure TSprvEmit_alloc.AllocSpirvID(P:PsrRefId);
begin
 RefIdAlloc.FetchSpirvID(P);
end;

procedure TSprvEmit_alloc.AllocBinding;
var
 FBinding:Integer;
begin
 InputList .AllocBinding;
 OutputList.AllocBinding;

 VertLayoutList.AllocBinding;
 FragLayoutList.AllocBinding;

 FBinding:=0;

 UniformList.AllocBinding(FBinding);
 BufferList .AllocBinding(FBinding);
end;

procedure TSprvEmit_alloc.AllocTypeBinding;
var
 node:PsrType;
begin
 node:=TypeList.First;
 While (node<>nil) do
 begin

  case node^.OpId of

   Op.OpTypeArray,
   Op.OpTypeRuntimeArray:
    begin
     DecorateList.OpDecorate(node,Decoration.ArrayStride,node^.array_stride);
    end;

   Op.OpTypeFloat:
     begin
      case node^.dtype.BitSize of
       16:AddCapability(Capability.Float16);
       64:AddCapability(Capability.Float64);
       else;
      end;
     end;

   Op.OpTypeInt:
     begin
      case node^.dtype.BitSize of
        8:AddCapability(Capability.Int8);
       16:AddCapability(Capability.Int16);
       64:AddCapability(Capability.Int64);
       else;
      end;
     end;

   else;
  end;

  node:=node^.Next;
 end;
end;

procedure TSprvEmit_alloc.AllocOpListId(node:PspirvOp);
begin
 While (node<>nil) do
 begin
  AllocOpId(node);
  node:=node^.Next;
 end;
end;

procedure TSprvEmit_alloc.AllocEntryPoint;
var
 node:PSpirvOp;
begin
 node:=HeaderList.AddSpirvOp(Op.OpEntryPoint);

 node^.AddLiteral(FExecutionModel,ExecutionModel.GetStr(FExecutionModel));

 node^.AddParam(Main);
 node^.AddString(Main^.name);

 InputList     .AllocEntryPoint(node);
 VertLayoutList.AllocEntryPoint(node);
 FragLayoutList.AllocEntryPoint(node);
 OutputList    .AllocEntryPoint(node);
end;

procedure TSprvEmit_alloc.AllocHeader;
var
 node:PSpirvOp;
begin
 node:=HeaderList.AddSpirvOp(Op.OpMemoryModel);
 node^.AddLiteral(AddressingModel.Logical,AddressingModel.GetStr(AddressingModel.Logical));
 node^.AddLiteral(MemoryModel.GLSL450,MemoryModel.GetStr(MemoryModel.GLSL450));

 AllocEntryPoint;

 Case FExecutionModel of
  ExecutionModel.Fragment:
    begin
     node:=HeaderList.AddSpirvOp(Op.OpExecutionMode);
     node^.AddParam(Main);
     node^.AddLiteral(ExecutionMode.OriginUpperLeft,ExecutionMode.GetStr(ExecutionMode.OriginUpperLeft));

     if (foDepthReplacing in DecorateList.FfemOpSet) then
     begin
      node:=HeaderList.AddSpirvOp(Op.OpExecutionMode);
      node^.AddParam(Main);
      node^.AddLiteral(ExecutionMode.DepthReplacing,ExecutionMode.GetStr(ExecutionMode.DepthReplacing));
     end;

     if (foDepthGreater in DecorateList.FfemOpSet) then
     begin
      node:=HeaderList.AddSpirvOp(Op.OpExecutionMode);
      node^.AddParam(Main);
      node^.AddLiteral(ExecutionMode.DepthGreater,ExecutionMode.GetStr(ExecutionMode.DepthGreater));
     end;

     if (foDepthLess in DecorateList.FfemOpSet) then
     begin
      node:=HeaderList.AddSpirvOp(Op.OpExecutionMode);
      node^.AddParam(Main);
      node^.AddLiteral(ExecutionMode.DepthLess,ExecutionMode.GetStr(ExecutionMode.DepthLess));
     end;

     if (foDepthUnchanged in DecorateList.FfemOpSet) then
     begin
      node:=HeaderList.AddSpirvOp(Op.OpExecutionMode);
      node^.AddParam(Main);
      node^.AddLiteral(ExecutionMode.DepthUnchanged,ExecutionMode.GetStr(ExecutionMode.DepthUnchanged));
     end;

    end;
  ExecutionModel.GLCompute:
    begin
     node:=HeaderList.AddSpirvOp(Op.OpExecutionMode);
     node^.AddParam(Main);
     node^.AddLiteral(ExecutionMode.LocalSize,ExecutionMode.GetStr(ExecutionMode.LocalSize));
     node^.AddLiteral(FLocalSize.x);
     node^.AddLiteral(FLocalSize.y);
     node^.AddLiteral(FLocalSize.z);
    end;
 end;

end;

procedure TSprvEmit_alloc.AllocListId(node:PsrNode);
begin
 While (node<>nil) do
 begin
  AllocSpirvID(node^.GetRef);
  node:=node^.Next;
 end;
end;

procedure TSprvEmit_alloc.AllocFuncId;
var
 pFunc:PSpirvFunc;
begin
 pFunc:=FuncList.First;
 While (pFunc<>nil) do
 begin
  AllocOpBlock(pFunc^.pTop);
  pFunc:=pFunc^.Next;
 end;
end;

procedure TSprvEmit_alloc.AllocOpId(node:PSpirvOp);
var
 Param:POpParamNode;
 Info:Op.TOpInfo;
 pReg:PsrRegNode;
begin
 if (node=nil) then Exit;

 Info:=Op.GetInfo(node^.OpId);

 if Info.result then //dst
 begin
  Assert(node^.pDst<>nil,'AllocOp$1');
  if (node^.pDst<>nil) then
  begin
   AllocSpirvID(node^.pDst^.GetRef);
  end;
 end else
 begin  //no dst
  if (node^.pDst<>nil) then
  begin
   AllocSpirvID(node^.pDst^.GetRef);
  end;
 end;

 if Info.rstype then //dst type
 begin
  if (node^.pType=nil) then
  begin
   pReg:=node^.pDst^.AsType(ntReg);
   Assert(pReg<>nil,'AllocOp$2');
   Assert(pReg^.dtype<>dtUnknow,'AllocOp$3');
   if (pReg<>nil) then
   begin
    node^.pType:=TypeList.Fetch(pReg^.dtype);
   end;
  end;
 end;

 Param:=node^.ParamFirst;
 While (Param<>nil) do
 begin
  AllocSpirvID(Param^.Value^.GetRef);
  Param:=Param^.Next;
 end;

end;

procedure TSprvEmit_alloc.AllocOpBlock(pBlock:PsrOpBlock);
var
 node:PSpirvOp;
begin
 if (pBlock=nil) then Exit;
 node:=pBlock^.First;
 While (node<>nil) do
 begin
  if node^.IsType(ntOp) then
  begin
   AllocOpId(node);
  end;
  node:=flow_down_next_up(node);
 end;
end;


end.

