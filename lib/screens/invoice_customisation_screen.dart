import 'package:flutter/material.dart';
import '../services/invoice_template_service.dart';

class InvoiceCustomisationScreen extends StatefulWidget {
  const InvoiceCustomisationScreen({super.key});
  @override State<InvoiceCustomisationScreen> createState()=>_InvoiceCustomisationScreenState();
}
class _InvoiceCustomisationScreenState extends State<InvoiceCustomisationScreen>{
  late String size; late Map<String,dynamic> value; bool saving=false; bool preview=true;
  @override void initState(){super.initState();size=InvoiceTemplateService.selected;value=InvoiceTemplateService.load(size);}
  void setValue(String k,dynamic v)=>setState(()=>value[k]=v);
  void selectSize(String v){setState((){size=v;value=InvoiceTemplateService.load(v);});}
  List<String> get selected=>(value['columns'] as List).cast<String>();
  void toggleColumn(String id,bool enabled){final next=List<String>.from(selected);if(enabled&&!next.contains(id))next.add(id);if(!enabled)next.remove(id);setValue('columns',next);}
  Future<void> save()async{setState(()=>saving=true);try{await InvoiceTemplateService.save(size,value);await InvoiceTemplateService.select(size);if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$size template saved')));}finally{if(mounted)setState(()=>saving=false);}}
  Future<void> restore()async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Restore default?'),content:Text('Replace the customised $size template with its original default?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Restore'))]));if(ok==true){await InvoiceTemplateService.restore(size);setState(()=>value=InvoiceTemplateService.load(size));}}
  Widget section(String title,List<Widget> children)=>Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:10),...children])));
  Widget toggle(String k,String label)=>SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(label),value:value[k]==true,onChanged:(v)=>setValue(k,v));
  Widget field(String k,String label,{int lines=1})=>TextFormField(key:ValueKey('$size-$k'),initialValue:value[k]?.toString()??'',maxLines:lines,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),onChanged:(v)=>setValue(k,v));
  @override Widget build(BuildContext context){
    final compact=size=='58mm'||size=='80mm';final warnings=InvoiceTemplateService.validate(value);
    return Scaffold(appBar:AppBar(title:const Text('Invoice Customisation'),actions:[IconButton(onPressed:restore,icon:const Icon(Icons.restart_alt),tooltip:'Restore defaults'),IconButton(onPressed:()=>setState(()=>preview=!preview),icon:const Icon(Icons.preview),tooltip:'Toggle preview')]),
      body:LayoutBuilder(builder:(context,c){
        final wide=c.maxWidth>=900;
        final editor=ListView(padding:const EdgeInsets.all(16),children:[
          section('Paper & template',[DropdownButtonFormField<String>(value:size,decoration:const InputDecoration(labelText:'Default paper size',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'58mm',child:Text('58mm POS')),DropdownMenuItem(value:'80mm',child:Text('80mm POS')),DropdownMenuItem(value:'A5',child:Text('A5')),DropdownMenuItem(value:'A4',child:Text('A4'))],onChanged:(v){if(v!=null)selectSize(v);}),const SizedBox(height:10),field('name','Template name'),const Text('Each paper size has its own saved template. This controls invoice layout; pair or select the physical printer separately in Printer Settings.')]),
          section('Header',[field('headerTitle','Invoice heading'),DropdownButtonFormField<String>(value:value['headerAlignment'],decoration:const InputDecoration(labelText:'Header alignment',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'left',child:Text('Left')),DropdownMenuItem(value:'center',child:Text('Centre')),DropdownMenuItem(value:'right',child:Text('Right'))],onChanged:(v){if(v!=null)setValue('headerAlignment',v);}),toggle('showLogo','Show logo'),toggle('showBusinessName','Show business name'),toggle('showAddress','Show address'),toggle('showPhone','Show phone'),toggle('showEmail','Show email'),toggle('showBusinessGstin','Show business GSTIN'),toggle('showCustomerPhone','Show customer phone'),toggle('showCustomerGstin','Show customer GSTIN')]),
          section('Table columns',[const Text('Enable the columns you need. The selected order is used in the invoice.'),for(final col in InvoiceTemplateService.columns)CheckboxListTile(contentPadding:EdgeInsets.zero,value:selected.contains(col['id']),title:Text(col['label']!),onChanged:(v)=>toggleColumn(col['id']!,v==true)),if(selected.length>1)ReorderableListView(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),onReorder:(oldIndex,newIndex){final next=List<String>.from(selected);if(newIndex>oldIndex)newIndex--;final item=next.removeAt(oldIndex);next.insert(newIndex,item);setValue('columns',next);},children:[for(final id in selected)ListTile(key:ValueKey('order-$id'),dense:true,leading:const Icon(Icons.drag_handle),title:Text(InvoiceTemplateService.columns.firstWhere((e)=>e['id']==id)['label']!))]),for(final id in selected)TextFormField(key:ValueKey('label-$size-$id'),initialValue:(value['columnLabels'] as Map?)?[id]?.toString()??InvoiceTemplateService.columns.firstWhere((e)=>e['id']==id)['label']!,decoration:InputDecoration(labelText:'Column label - '+InvoiceTemplateService.columns.firstWhere((e)=>e['id']==id)['label']!),onChanged:(v){final labels=Map<String,dynamic>.from((value['columnLabels'] as Map?)??{});labels[id]=v;setValue('columnLabels',labels);}),toggle('showTableBorders','Show table borders')]),
          section('Footer',[field('footerText','Footer message',lines:2),field('termsText','Terms and conditions',lines:3),toggle('showPaymentMethod','Show payment method'),toggle('showQr','Show UPI QR when available'),if(!compact)toggle('showAmountInWords','Show amount in words'),DropdownButtonFormField<String>(value:value['footerAlignment'],decoration:const InputDecoration(labelText:'Footer alignment',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'left',child:Text('Left')),DropdownMenuItem(value:'center',child:Text('Centre')),DropdownMenuItem(value:'right',child:Text('Right'))],onChanged:(v){if(v!=null)setValue('footerAlignment',v);})]),
          section('Typography & spacing',[Text('Font size: '+(value['fontSize'] as num).toStringAsFixed(1)+' pt'),Slider(min:compact?6:7,max:compact?12:18,divisions:compact?12:22,value:((value['fontSize'] as num).toDouble()).clamp(compact?6.0:7.0,compact?12.0:18.0),onChanged:(v)=>setValue('fontSize',v)),Text('Margins: '+(value['marginMm'] as num).toStringAsFixed(1)+' mm'),Slider(min:0,max:compact?5:25,divisions:compact?10:25,value:((value['marginMm'] as num).toDouble()).clamp(0.0,compact?5.0:25.0),onChanged:(v)=>setValue('marginMm',v)),DropdownButtonFormField<String>(value:value['accent'],decoration:const InputDecoration(labelText:'Accent colour',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'blue',child:Text('Blue')),DropdownMenuItem(value:'green',child:Text('Green')),DropdownMenuItem(value:'purple',child:Text('Purple')),DropdownMenuItem(value:'teal',child:Text('Teal')),DropdownMenuItem(value:'orange',child:Text('Orange')),DropdownMenuItem(value:'black',child:Text('Monochrome'))],onChanged:(v){if(v!=null)setValue('accent',v);})]),
          if(warnings.isNotEmpty)section('Layout guidance',[for(final w in warnings)ListTile(dense:true,leading:const Icon(Icons.warning_amber,color:Colors.orange),title:Text(w))]),
          FilledButton.icon(onPressed:saving||selected.isEmpty?null:save,icon:saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save),label:const Text('Save template')),const SizedBox(height:24)]);
        final view=TemplatePreview(size:size,value:value,warnings:warnings);
        if(wide)return Row(children:[Expanded(flex:5,child:editor),if(preview)const VerticalDivider(width:1),if(preview)Expanded(flex:4,child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:view))]);
        return Column(children:[if(preview)Expanded(flex:3,child:SingleChildScrollView(padding:const EdgeInsets.all(16),child:view)),if(preview)const Divider(),Expanded(flex:5,child:editor)]);
      }));
  }
}
class TemplatePreview extends StatelessWidget{
  final String size;final Map<String,dynamic> value;final List<String>warnings;
  const TemplatePreview({super.key,required this.size,required this.value,required this.warnings});
  @override Widget build(BuildContext context){
    final compact=size=='58mm'||size=='80mm';final width=size=='58mm'?210.0:size=='80mm'?280.0:size=='A5'?360.0:440.0;final cols=(value['columns'] as List).cast<String>();
    final alignment=value['headerAlignment']=='left'?CrossAxisAlignment.start:value['headerAlignment']=='right'?CrossAxisAlignment.end:CrossAxisAlignment.center;
    final footer=value['footerAlignment']=='left'?TextAlign.left:value['footerAlignment']=='right'?TextAlign.right:TextAlign.center;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Live preview - $size',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:12),
      Center(child:Container(width:width,constraints:const BoxConstraints(maxWidth:double.infinity),padding:EdgeInsets.all((value['marginMm'] as num).toDouble()+10),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:Colors.grey),boxShadow:const [BoxShadow(color:Color(0x18000000),blurRadius:10)]),
        child:DefaultTextStyle(style:TextStyle(color:Colors.black,fontSize:(value['fontSize'] as num).toDouble()),child:Column(crossAxisAlignment:alignment,mainAxisSize:MainAxisSize.min,children:[
          if(value['showLogo']==true&&!compact)const Icon(Icons.store,size:28),
          if(value['showBusinessName']==true)const Text('YOUR BUSINESS NAME',style:TextStyle(fontWeight:FontWeight.bold,fontSize:15)),
          if(value['showAddress']==true)const Text('Business address, City, PIN'),
          if(value['showPhone']==true)const Text('Phone: 98765 43210'),
          if(value['showBusinessGstin']==true)const Text('GSTIN: 32ABCDE1234F1Z5'),
          const Divider(color:Colors.black),Text(value['headerTitle'].toString(),style:const TextStyle(fontWeight:FontWeight.bold)),
          const Align(alignment:Alignment.centerLeft,child:Text('Invoice: INV-0001\nDate: 01 Nov 2026\nCustomer: Sample Customer')),const Divider(color:Colors.black),
          Row(children:[for(final id in cols)Expanded(child:Text(((value['columnLabels'] as Map?)?[id]?.toString().isNotEmpty==true?(value['columnLabels'] as Map)[id].toString():InvoiceTemplateService.columns.firstWhere((e)=>e['id']==id)['label']!),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold)))]),
          for(var i=0;i<3;i++)Row(children:[for(final id in cols)Expanded(child:Text(id=='product'?['Rice 5kg','Cooking Oil','Wheat Flour'][i]:id=='quantity'?['2','1','3'][i]:id=='rate'?['₹450','₹180','₹65'][i]:id=='amount'?['₹900','₹180','₹195'][i]:id=='serial'?'1':id=='hsn'?'1006':id=='gst_rate'?'5%':id=='tax'?'₹45':'pcs',maxLines:2,overflow:TextOverflow.ellipsis))]),
          if(value['showTableBorders']==true)const Divider(color:Colors.black),
          const Text('Subtotal: ₹1,275\nGST: ₹45\nGRAND TOTAL: ₹1,320',style:TextStyle(fontWeight:FontWeight.bold)),
          if(value['showPaymentMethod']==true)const Text('Payment: UPI'),
          if(value['showAmountInWords']==true&&!compact)const Text('Amount in words: One Thousand Three Hundred Twenty Rupees Only'),
          if(value['showQr']==true&&!compact)const Icon(Icons.qr_code_2,size:40),
          if(value['footerText'].toString().isNotEmpty)Text(value['footerText'].toString(),textAlign:footer,style:const TextStyle(fontWeight:FontWeight.bold)),
          if(value['termsText'].toString().isNotEmpty)Text(value['termsText'].toString(),textAlign:footer)])))),
      for(final w in warnings)Padding(padding:const EdgeInsets.only(top:8),child:Text('Warning: '+w,style:Theme.of(context).textTheme.bodySmall))]);
  }
}
