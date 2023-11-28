import SwiftUI

struct HistoryView: View {
    
    @ObservedObject private var dataManager = DataManager.shared
    
    var body: some View {
        NavigationStack{
            VStack{
                ScrollView{
                    VStack(alignment:.center) {
                        HStack(alignment: .bottom) {
                            Text("Histórico")
                                .font(Font.custom("Poppins", size: 30) .weight(.bold))
                                .foregroundColor(Color(red: 0.61, green: 0.13, blue: 0.15))
                                .padding(.leading, 40)
                            
                            Spacer()
                            Image("bichinhos")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 110)
                                .padding(.top)
                                .padding(.bottom, 6)
                                .padding(.trailing, 43)
                        }
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 323, height: 1)
                            .background(Color(red: 0.61, green: 0.13, blue: 0.15))
                    }
                    .padding(.bottom, 10)
                    LazyVGrid(columns: [GridItem(.flexible())]) {
                        ForEach(dataManager.allContent) { history in
                            ContentCard(watchedContent: history)
                        }.padding(.vertical, 8)
                    }
                }
                

            }
            .overlay {
                VStack{
                    Spacer()
                    HStack{
                        Spacer()
                        Button {
                            dataManager.clearHistory()
                        } label: {
                            Text("Limpar Histórico")
                                .font(.system(size: 14))
                                .fontWeight(.bold)
                                .foregroundColor(.white).frame(width: 126, height: 50, alignment: .center)
                                .background(Color("Azul_Escuro"))
                                .cornerRadius(16)
                        }
                        .padding(.trailing)
                    }.padding(.bottom, 8)
                }
            }
        }
    }
}



struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
