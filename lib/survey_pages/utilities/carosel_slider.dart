import 'package:carousel_slider/carousel_slider.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NumberCarouselSlider extends StatefulWidget {
  final Function(int)? onNumberChanged;
  final int startValue;
  final CarouselController carouselController;

  const NumberCarouselSlider({
    this.onNumberChanged,
    Key? key,
    required this.startValue,
    required this.carouselController,
  }) : super(key: key);

  @override
  State<NumberCarouselSlider> createState() => _NumberCarouselSliderState();
}

class _NumberCarouselSliderState extends State<NumberCarouselSlider> {
  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    var availableSeconds = [0];
    for (int i = 30; i <= 180; i += 30) {
      availableSeconds.add(i);
    }
    int initialPage = availableSeconds.indexOf(widget.startValue);

    return CarouselSlider(
      carouselController: widget.carouselController,
      options: CarouselOptions(
        height: 70,
        autoPlay: false,
        enableInfiniteScroll: false,
        initialPage: initialPage,
        scrollDirection: Axis.vertical,
        enlargeCenterPage: true,
        onPageChanged: (index, reason) {
          if (widget.onNumberChanged != null) {
            widget.onNumberChanged!(availableSeconds[index]);
          }
        },
      ),
      items: availableSeconds.map((seconds) {
        return Builder(
          builder: (BuildContext context) {
            return Padding(
              padding: const EdgeInsets.only(
                left: 40,
                right: 40,
              ),
              child: Card(
                shadowColor: getButtonColor(context),
                elevation: 5,
                child: Center(
                  child: Text(
                    seconds == 0 ? "Unlimited" : "$seconds sec",
                    style: TextStyle(
                        fontSize: fontSize, color: getListTileColor(context)),
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
